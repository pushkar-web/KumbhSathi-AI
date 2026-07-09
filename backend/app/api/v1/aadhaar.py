"""
KumbhSathi AI — Aadhaar Card OCR & Matching API Routes
"""
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_, func
from typing import Optional
from datetime import datetime, timezone
import uuid
import os
import re

from app.core.database import get_db
from app.core.security import get_current_user, require_role, hash_aadhaar
from app.core.config import settings
from app.models.models import AadhaarRecord, MissingPerson, TimelineEvent

router = APIRouter()


@router.post("/extract")
async def extract_aadhaar(
    file: UploadFile = File(..., description="Photo of Aadhaar card"),
    current_user: dict = Depends(require_role("police", "admin")),
    db: AsyncSession = Depends(get_db)
):
    """
    Extract information from Aadhaar card using OCR.
    Supports English + Hindi text.
    Card image is NOT stored after processing.
    """
    image_bytes = await file.read()
    
    # Save temporarily for OCR
    temp_path = os.path.join(settings.UPLOAD_DIR, "aadhaar", f"temp_{uuid.uuid4()}.jpg")
    os.makedirs(os.path.dirname(temp_path), exist_ok=True)
    with open(temp_path, "wb") as f:
        f.write(image_bytes)
    
    try:
        import easyocr
        
        reader = easyocr.Reader(['en', 'hi'], gpu=False)
        results = reader.readtext(temp_path)
        
        # Extract text blocks
        text_blocks = [r[1] for r in results]
        full_text = " ".join(text_blocks)
        
        # Extract Aadhaar number (12 digits: XXXX XXXX XXXX)
        aadhaar_pattern = re.compile(r'\d{4}\s?\d{4}\s?\d{4}')
        aadhaar_match = aadhaar_pattern.search(full_text)
        aadhaar_number = aadhaar_match.group().replace(" ", "") if aadhaar_match else None
        
        # Extract DOB
        dob_pattern = re.compile(r'(\d{2}/\d{2}/\d{4})')
        dob_match = dob_pattern.search(full_text)
        dob = dob_match.group() if dob_match else None
        
        # Extract gender
        gender = None
        gender_keywords = {
            'male': 'Male', 'female': 'Female',
            'MALE': 'Male', 'FEMALE': 'Female',
            'पुरुष': 'Male', 'महिला': 'Female',
            'Male': 'Male', 'Female': 'Female',
        }
        for keyword, value in gender_keywords.items():
            if keyword in full_text:
                gender = value
                break
        
        # Extract name (typically the first non-government text after "Government of India")
        name = None
        for i, block in enumerate(text_blocks):
            if any(skip in block.lower() for skip in ['government', 'india', 'aadhaar', 'unique', 'authority', 'भारत']):
                continue
            if len(block) > 3 and block.replace(" ", "").isalpha():
                name = block
                break
        
        # Extract address (remaining text blocks after name/DOB/gender)
        address_parts = []
        for block in text_blocks:
            if block != name and not aadhaar_pattern.search(block) and not dob_pattern.search(block):
                if len(block) > 5 and not any(skip in block.lower() for skip in ['government', 'india', 'aadhaar']):
                    address_parts.append(block)
        address = ", ".join(address_parts[-3:]) if address_parts else None
        
        # Parse state/district from address
        state = None
        district = None
        if address:
            # Common Indian states
            states = ['Bihar', 'Uttar Pradesh', 'Rajasthan', 'Maharashtra', 'Tamil Nadu', 
                      'Kerala', 'Gujarat', 'Delhi', 'Karnataka', 'Madhya Pradesh',
                      'Andhra Pradesh', 'Telangana', 'Odisha', 'Assam', 'Punjab',
                      'Haryana', 'Jharkhand', 'Chhattisgarh']
            for s in states:
                if s.lower() in address.lower():
                    state = s
                    break
        
        # Delete the temporary image (privacy)
        os.remove(temp_path)
        
        # Calculate confidence
        confidence = 0.0
        if aadhaar_number: confidence += 0.4
        if name: confidence += 0.2
        if dob: confidence += 0.15
        if gender: confidence += 0.1
        if address: confidence += 0.15
        
        return {
            "success": True,
            "extracted_data": {
                "aadhaar_number_masked": f"XXXX-XXXX-{aadhaar_number[-4:]}" if aadhaar_number else None,
                "name": name,
                "dob": dob,
                "gender": gender,
                "address": address,
                "state": state,
                "district": district,
            },
            "confidence": round(confidence, 2),
            "text_blocks_count": len(text_blocks),
            "aadhaar_detected": aadhaar_number is not None,
            "_aadhaar_hash": hash_aadhaar(aadhaar_number) if aadhaar_number else None,
        }
        
    except ImportError:
        os.remove(temp_path)
        return {
            "success": False,
            "message": "EasyOCR not available. Install easyocr package.",
            "extracted_data": {},
        }
    except Exception as e:
        if os.path.exists(temp_path):
            os.remove(temp_path)
        raise HTTPException(status_code=500, detail=f"OCR processing failed: {str(e)}")


@router.post("/match")
async def match_aadhaar(
    aadhaar_hash: str,
    name: Optional[str] = None,
    dob: Optional[str] = None,
    gender: Optional[str] = None,
    state: Optional[str] = None,
    district: Optional[str] = None,
    current_user: dict = Depends(require_role("police", "admin")),
    db: AsyncSession = Depends(get_db)
):
    """
    Match extracted Aadhaar data against the missing persons database.
    Multi-level matching: hash match → name+age → name+state
    """
    matches = []
    
    # Level 1: Exact Aadhaar hash match
    hash_result = await db.execute(
        select(AadhaarRecord)
        .where(AadhaarRecord.aadhaar_hash == aadhaar_hash)
        .where(AadhaarRecord.match_status != "no_match")
    )
    hash_matches = hash_result.scalars().all()
    
    for record in hash_matches:
        if record.missing_person_id:
            mp_result = await db.execute(
                select(MissingPerson).where(MissingPerson.id == record.missing_person_id)
            )
            mp = mp_result.scalar_one_or_none()
            if mp:
                matches.append({
                    "match_level": 1,
                    "confidence": 100.0,
                    "method": "aadhaar_hash_exact",
                    "case_id": mp.case_id,
                    "person_name": mp.missing_person_name,
                    "status": mp.status,
                    "age_band": mp.age_band,
                    "gender": mp.gender,
                    "state": mp.state,
                    "last_seen_location": mp.last_seen_location,
                })
    
    # Level 2: Name + age/gender fuzzy match
    if name and not matches:
        name_query = select(MissingPerson).where(
            MissingPerson.missing_person_name.isnot(None)
        )
        
        if gender:
            name_query = name_query.where(MissingPerson.gender == gender)
        if state:
            name_query = name_query.where(MissingPerson.state == state)
        
        name_result = await db.execute(name_query)
        candidates = name_result.scalars().all()
        
        for mp in candidates:
            if mp.missing_person_name:
                # Simple fuzzy matching
                name_lower = name.lower().strip()
                mp_name_lower = mp.missing_person_name.lower().strip()
                
                # Check if names share significant overlap
                name_parts = set(name_lower.split())
                mp_parts = set(mp_name_lower.split())
                overlap = name_parts & mp_parts
                
                if len(overlap) >= 1 and len(overlap) / max(len(name_parts), len(mp_parts)) >= 0.5:
                    confidence = 70.0 + (len(overlap) / max(len(name_parts), len(mp_parts))) * 25
                    
                    if gender and mp.gender == gender:
                        confidence += 5
                    if state and mp.state == state:
                        confidence += 5
                    
                    matches.append({
                        "match_level": 2,
                        "confidence": min(round(confidence, 1), 95.0),
                        "method": "name_fuzzy",
                        "case_id": mp.case_id,
                        "person_name": mp.missing_person_name,
                        "status": mp.status,
                        "age_band": mp.age_band,
                        "gender": mp.gender,
                        "state": mp.state,
                        "last_seen_location": mp.last_seen_location,
                    })
    
    # Sort by confidence
    matches.sort(key=lambda x: x["confidence"], reverse=True)
    
    # Store Aadhaar record
    record = AadhaarRecord(
        aadhaar_hash=aadhaar_hash,
        name_extracted=name,
        gender_extracted=gender,
        state_extracted=state,
        district_extracted=district,
        match_status="matched" if matches else "no_match",
        matched_person_id=None,  # Set after officer confirmation
        created_by=uuid.UUID(current_user["sub"]),
    )
    db.add(record)
    
    return {
        "success": True,
        "match_count": len(matches),
        "matches": matches[:10],  # Top 10
        "aadhaar_record_id": str(record.id),
    }


@router.get("/records/{case_id}")
async def get_aadhaar_records(
    case_id: str,
    current_user: dict = Depends(require_role("police", "admin")),
    db: AsyncSession = Depends(get_db)
):
    """Get Aadhaar records associated with a case."""
    mp_result = await db.execute(select(MissingPerson.id).where(MissingPerson.case_id == case_id))
    mp_id = mp_result.scalar_one_or_none()
    if not mp_id:
        raise HTTPException(status_code=404, detail="Case not found")
    
    result = await db.execute(
        select(AadhaarRecord).where(
            or_(AadhaarRecord.missing_person_id == mp_id, AadhaarRecord.matched_person_id == mp_id)
        )
    )
    records = result.scalars().all()
    
    return {
        "case_id": case_id,
        "records": [
            {
                "id": str(r.id),
                "name_extracted": r.name_extracted,
                "gender_extracted": r.gender_extracted,
                "state_extracted": r.state_extracted,
                "district_extracted": r.district_extracted,
                "match_status": r.match_status,
                "raw_ocr_confidence": r.raw_ocr_confidence,
                "created_at": r.created_at.isoformat(),
            }
            for r in records
        ]
    }
