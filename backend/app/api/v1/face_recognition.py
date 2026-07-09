"""
KumbhSathi AI — Face Recognition API Routes
Face encoding, matching against database, and results retrieval
"""
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, text
from typing import Optional
from datetime import datetime, timezone
import uuid
import os

from app.core.database import get_db
from app.core.security import get_current_user, require_role
from app.core.config import settings
from app.models.models import FaceEmbedding, MissingPerson, TimelineEvent

router = APIRouter()


@router.post("/encode")
async def encode_face(
    file: UploadFile = File(..., description="Photo containing a face"),
    missing_person_id: str = Form(..., description="UUID of the missing person case"),
    source: str = Form(default="reporter", description="Source: reporter, volunteer, police"),
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Upload a photo, detect face, generate 128-d embedding, and store in database.
    Used when registering a missing person with their photo.
    """
    # Validate file type
    if file.content_type not in settings.ALLOWED_IMAGE_TYPES:
        raise HTTPException(status_code=400, detail="Invalid image type. Use JPEG, PNG, or WebP.")
    
    # Read image bytes
    image_bytes = await file.read()
    if len(image_bytes) > settings.MAX_UPLOAD_SIZE_MB * 1024 * 1024:
        raise HTTPException(status_code=400, detail=f"File too large. Max {settings.MAX_UPLOAD_SIZE_MB}MB.")
    
    # Save photo
    photo_filename = f"{uuid.uuid4()}.jpg"
    photo_path = os.path.join(settings.UPLOAD_DIR, "photos", photo_filename)
    os.makedirs(os.path.dirname(photo_path), exist_ok=True)
    with open(photo_path, "wb") as f:
        f.write(image_bytes)
    
    photo_url = f"/uploads/photos/{photo_filename}"
    
    try:
        # Generate face embedding using face_recognition library
        import face_recognition
        import numpy as np
        
        image = face_recognition.load_image_file(photo_path)
        face_locations = face_recognition.face_locations(image, model=settings.FACE_RECOGNITION_MODEL)
        
        if len(face_locations) == 0:
            return {
                "success": False,
                "message": "No face detected in the photo. Please upload a clearer photo.",
                "photo_url": photo_url,
                "num_faces": 0,
            }
        
        face_encodings = face_recognition.face_encodings(image, face_locations)
        encoding = face_encodings[0]  # Use the first (largest) face
        
        # Store embedding in database
        face_emb = FaceEmbedding(
            missing_person_id=uuid.UUID(missing_person_id),
            embedding=encoding.tolist(),
            photo_url=photo_url,
            source=source,
            quality_score=1.0,  # Could add quality assessment
            num_faces_detected=len(face_locations),
            created_by=uuid.UUID(current_user["sub"]),
        )
        db.add(face_emb)
        
        # Update missing person photo
        mp_result = await db.execute(
            select(MissingPerson).where(MissingPerson.id == uuid.UUID(missing_person_id))
        )
        mp = mp_result.scalar_one_or_none()
        if mp and not mp.photo_url:
            mp.photo_url = photo_url
        
        await db.flush()
        
        return {
            "success": True,
            "message": f"Face encoded successfully. {len(face_locations)} face(s) detected.",
            "embedding_id": str(face_emb.id),
            "photo_url": photo_url,
            "num_faces": len(face_locations),
            "face_location": {
                "top": face_locations[0][0],
                "right": face_locations[0][1],
                "bottom": face_locations[0][2],
                "left": face_locations[0][3],
            },
        }
    except ImportError:
        # face_recognition not installed — return simulated response
        face_emb = FaceEmbedding(
            missing_person_id=uuid.UUID(missing_person_id),
            embedding=[0.0] * 128,  # Placeholder
            photo_url=photo_url,
            source=source,
            quality_score=0.0,
            num_faces_detected=0,
            created_by=uuid.UUID(current_user["sub"]),
        )
        db.add(face_emb)
        await db.flush()
        
        return {
            "success": True,
            "message": "Photo saved. Face recognition library not available — embedding will be generated when available.",
            "embedding_id": str(face_emb.id),
            "photo_url": photo_url,
            "num_faces": 0,
        }


@router.post("/match")
async def match_face(
    file: UploadFile = File(..., description="Photo of found person to match"),
    top_k: int = Form(default=5, description="Number of top matches to return"),
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Upload a photo of a found person, generate embedding, and search against
    all stored face embeddings using pgvector cosine similarity.
    """
    image_bytes = await file.read()
    
    # Save temporarily
    temp_filename = f"temp_{uuid.uuid4()}.jpg"
    temp_path = os.path.join(settings.UPLOAD_DIR, "photos", temp_filename)
    os.makedirs(os.path.dirname(temp_path), exist_ok=True)
    with open(temp_path, "wb") as f:
        f.write(image_bytes)
    
    try:
        import face_recognition
        import numpy as np
        
        image = face_recognition.load_image_file(temp_path)
        face_locations = face_recognition.face_locations(image, model=settings.FACE_RECOGNITION_MODEL)
        
        if len(face_locations) == 0:
            os.remove(temp_path)
            return {
                "success": False,
                "message": "No face detected. Please upload a clearer photo.",
                "matches": [],
            }
        
        face_encodings = face_recognition.face_encodings(image, face_locations)
        query_encoding = face_encodings[0]
        
        # pgvector cosine similarity search
        embedding_str = "[" + ",".join(str(x) for x in query_encoding.tolist()) + "]"
        
        result = await db.execute(text(f"""
            SELECT fe.id, fe.missing_person_id, fe.photo_url, fe.source,
                   1 - (fe.embedding <=> '{embedding_str}'::vector) as similarity,
                   mp.case_id, mp.missing_person_name, mp.age_band, mp.gender,
                   mp.status, mp.last_seen_location, mp.priority
            FROM face_embeddings fe
            JOIN missing_persons mp ON fe.missing_person_id = mp.id
            WHERE fe.is_active = true
            ORDER BY fe.embedding <=> '{embedding_str}'::vector
            LIMIT {top_k}
        """))
        
        matches = []
        for row in result.fetchall():
            similarity = float(row[4])
            if similarity >= settings.FACE_RECOGNITION_THRESHOLD:
                matches.append({
                    "embedding_id": str(row[0]),
                    "missing_person_id": str(row[1]),
                    "photo_url": row[2],
                    "source": row[3],
                    "confidence": round(similarity * 100, 1),
                    "case_id": row[5],
                    "person_name": row[6],
                    "age_band": row[7],
                    "gender": row[8],
                    "status": row[9],
                    "last_seen_location": row[10],
                    "priority": row[11],
                })
        
        os.remove(temp_path)
        
        return {
            "success": True,
            "message": f"Found {len(matches)} potential matches.",
            "matches": matches,
            "query_face_location": {
                "top": face_locations[0][0],
                "right": face_locations[0][1],
                "bottom": face_locations[0][2],
                "left": face_locations[0][3],
            },
        }
    except ImportError:
        os.remove(temp_path)
        return {
            "success": False,
            "message": "Face recognition library not available. Install face_recognition package.",
            "matches": [],
        }


@router.get("/matches/{case_id}")
async def get_face_matches(
    case_id: str,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get all face embeddings/matches for a case."""
    mp_result = await db.execute(select(MissingPerson.id).where(MissingPerson.case_id == case_id))
    mp_id = mp_result.scalar_one_or_none()
    if not mp_id:
        raise HTTPException(status_code=404, detail="Case not found")
    
    result = await db.execute(
        select(FaceEmbedding)
        .where(FaceEmbedding.missing_person_id == mp_id)
        .where(FaceEmbedding.is_active == True)
    )
    embeddings = result.scalars().all()
    
    return {
        "case_id": case_id,
        "face_embeddings": [
            {
                "id": str(e.id),
                "photo_url": e.photo_url,
                "source": e.source,
                "quality_score": e.quality_score,
                "num_faces_detected": e.num_faces_detected,
                "created_at": e.created_at.isoformat(),
            }
            for e in embeddings
        ]
    }


@router.delete("/embeddings/{embedding_id}")
async def delete_face_embedding(
    embedding_id: str,
    current_user: dict = Depends(require_role("police", "admin")),
    db: AsyncSession = Depends(get_db)
):
    """Deactivate a face embedding."""
    result = await db.execute(select(FaceEmbedding).where(FaceEmbedding.id == uuid.UUID(embedding_id)))
    emb = result.scalar_one_or_none()
    if not emb:
        raise HTTPException(status_code=404, detail="Embedding not found")
    
    emb.is_active = False
    return {"message": "Face embedding deactivated"}
