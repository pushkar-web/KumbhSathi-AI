"""
KumbhSathi AI — Cases API Routes
CRUD for missing persons cases, timeline, duplicates
"""
from fastapi import APIRouter, Depends, HTTPException, status, Query, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, or_, and_
from sqlalchemy.orm import selectinload
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime, timezone
import uuid
import os

from app.core.database import get_db
from app.core.security import get_current_user, require_role
from app.core.config import settings
from app.models.models import MissingPerson, TimelineEvent, DuplicateCase, Report

router = APIRouter()


# ============================================================
# Pydantic Schemas
# ============================================================
class CaseCreateRequest(BaseModel):
    missing_person_name: Optional[str] = None
    gender: Optional[str] = None
    age_band: Optional[str] = None
    state: Optional[str] = None
    district: Optional[str] = None
    language: Optional[str] = None
    physical_description: Optional[str] = None
    clothing_description: Optional[str] = None
    last_seen_location: Optional[str] = None
    last_seen_lat: Optional[float] = None
    last_seen_lng: Optional[float] = None
    reporter_mobile: Optional[str] = None
    reporting_center: Optional[str] = None
    remarks: Optional[str] = None


class CaseUpdateRequest(BaseModel):
    missing_person_name: Optional[str] = None
    gender: Optional[str] = None
    age_band: Optional[str] = None
    physical_description: Optional[str] = None
    clothing_description: Optional[str] = None
    last_seen_location: Optional[str] = None
    priority: Optional[str] = None
    remarks: Optional[str] = None


class StatusUpdateRequest(BaseModel):
    status: str = Field(..., pattern=r'^(Pending|Searching|Reunited|Transferred to hospital|Unresolved)$')
    notes: Optional[str] = None


class TimelineEventRequest(BaseModel):
    event_type: str
    title: Optional[str] = None
    description: Optional[str] = None
    metadata: Optional[dict] = None


class CaseListResponse(BaseModel):
    cases: list
    total: int
    page: int
    page_size: int


# ============================================================
# Helper: Generate Case ID
# ============================================================
async def generate_case_id(db: AsyncSession) -> str:
    result = await db.execute(select(func.count(MissingPerson.id)))
    count = result.scalar() or 0
    return f"KMP-2027-{count + 2501:05d}"


# ============================================================
# Routes
# ============================================================
@router.post("", status_code=status.HTTP_201_CREATED)
async def create_case(
    request: CaseCreateRequest,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Create a new missing person case."""
    case_id = await generate_case_id(db)
    
    # Determine initial priority based on age
    priority = "Medium"
    if request.age_band in ("0-12",):
        priority = "Critical"
    elif request.age_band in ("13-17", "80+"):
        priority = "High"
    elif request.age_band in ("71-80",):
        priority = "Medium"
    
    case = MissingPerson(
        case_id=case_id,
        reporter_id=uuid.UUID(current_user["sub"]),
        missing_person_name=request.missing_person_name,
        gender=request.gender,
        age_band=request.age_band,
        state=request.state,
        district=request.district,
        language=request.language,
        physical_description=request.physical_description,
        clothing_description=request.clothing_description,
        last_seen_location=request.last_seen_location,
        last_seen_lat=request.last_seen_lat,
        last_seen_lng=request.last_seen_lng,
        reporter_mobile=request.reporter_mobile,
        reporting_center=request.reporting_center,
        remarks=request.remarks,
        priority=priority,
        status="Pending",
        reported_at=datetime.now(timezone.utc),
    )
    db.add(case)
    await db.flush()
    
    # Create initial timeline event
    timeline = TimelineEvent(
        case_id=case.id,
        event_type="registered",
        title="Case Registered",
        description=f"Missing person case {case_id} registered by {current_user.get('name', 'Unknown')}",
        actor_id=uuid.UUID(current_user["sub"]),
        actor_name=current_user.get("name"),
    )
    db.add(timeline)
    
    # Create report record
    report = Report(
        missing_person_id=case.id,
        reporter_id=uuid.UUID(current_user["sub"]),
        source="text",
        raw_input=request.physical_description,
        language=request.language,
    )
    db.add(report)
    
    return {
        "id": str(case.id),
        "case_id": case.case_id,
        "status": case.status,
        "priority": priority,
        "message": "Case registered successfully",
    }


@router.get("")
async def list_cases(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    status: Optional[str] = None,
    priority: Optional[str] = None,
    age_band: Optional[str] = None,
    search: Optional[str] = None,
    location: Optional[str] = None,
    sort_by: str = Query("reported_at", pattern=r'^(reported_at|priority|status|case_id)$'),
    sort_order: str = Query("desc", pattern=r'^(asc|desc)$'),
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """List cases with filtering, sorting, and pagination."""
    query = select(MissingPerson)
    count_query = select(func.count(MissingPerson.id))
    
    # Role-based filtering
    if current_user.get("role") == "family":
        query = query.where(MissingPerson.reporter_id == uuid.UUID(current_user["sub"]))
        count_query = count_query.where(MissingPerson.reporter_id == uuid.UUID(current_user["sub"]))
    
    # Filters
    if status:
        query = query.where(MissingPerson.status == status)
        count_query = count_query.where(MissingPerson.status == status)
    if priority:
        query = query.where(MissingPerson.priority == priority)
        count_query = count_query.where(MissingPerson.priority == priority)
    if age_band:
        query = query.where(MissingPerson.age_band == age_band)
        count_query = count_query.where(MissingPerson.age_band == age_band)
    if location:
        query = query.where(MissingPerson.last_seen_location.ilike(f"%{location}%"))
        count_query = count_query.where(MissingPerson.last_seen_location.ilike(f"%{location}%"))
    if search:
        search_filter = or_(
            MissingPerson.missing_person_name.ilike(f"%{search}%"),
            MissingPerson.case_id.ilike(f"%{search}%"),
            MissingPerson.physical_description.ilike(f"%{search}%"),
        )
        query = query.where(search_filter)
        count_query = count_query.where(search_filter)
    
    # Sorting
    sort_column = getattr(MissingPerson, sort_by)
    if sort_order == "desc":
        query = query.order_by(sort_column.desc())
    else:
        query = query.order_by(sort_column.asc())
    
    # Pagination
    total_result = await db.execute(count_query)
    total = total_result.scalar()
    
    query = query.offset((page - 1) * page_size).limit(page_size)
    result = await db.execute(query)
    cases = result.scalars().all()
    
    return {
        "cases": [
            {
                "id": str(c.id),
                "case_id": c.case_id,
                "missing_person_name": c.missing_person_name,
                "gender": c.gender,
                "age_band": c.age_band,
                "status": c.status,
                "priority": c.priority,
                "last_seen_location": c.last_seen_location,
                "reported_at": c.reported_at.isoformat() if c.reported_at else None,
                "resolution_hours": c.resolution_hours,
                "photo_url": c.photo_url,
                "state": c.state,
                "district": c.district,
                "language": c.language,
                "reporting_center": c.reporting_center,
                "is_duplicate_report": c.is_duplicate_report,
            }
            for c in cases
        ],
        "total": total,
        "page": page,
        "page_size": page_size,
    }


@router.get("/{case_id}")
async def get_case(
    case_id: str,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get full case details by case_id."""
    result = await db.execute(
        select(MissingPerson)
        .options(
            selectinload(MissingPerson.timeline_events),
            selectinload(MissingPerson.assignments),
            selectinload(MissingPerson.predictions),
        )
        .where(MissingPerson.case_id == case_id)
    )
    case = result.scalar_one_or_none()
    
    if not case:
        raise HTTPException(status_code=404, detail="Case not found")
    
    return {
        "id": str(case.id),
        "case_id": case.case_id,
        "missing_person_name": case.missing_person_name,
        "gender": case.gender,
        "age_band": case.age_band,
        "state": case.state,
        "district": case.district,
        "language": case.language,
        "physical_description": case.physical_description,
        "clothing_description": case.clothing_description,
        "photo_url": case.photo_url,
        "last_seen_location": case.last_seen_location,
        "last_seen_lat": case.last_seen_lat,
        "last_seen_lng": case.last_seen_lng,
        "status": case.status,
        "priority": case.priority,
        "priority_score": case.priority_score,
        "reported_at": case.reported_at.isoformat() if case.reported_at else None,
        "reporting_center": case.reporting_center,
        "reporter_mobile": case.reporter_mobile,
        "resolution_hours": case.resolution_hours,
        "is_duplicate_report": case.is_duplicate_report,
        "remarks": case.remarks,
        "ai_extracted_data": case.ai_extracted_data,
        "timeline": [
            {
                "id": str(t.id),
                "event_type": t.event_type,
                "title": t.title,
                "description": t.description,
                "actor_name": t.actor_name,
                "created_at": t.created_at.isoformat(),
                "metadata": t.meta,
            }
            for t in (case.timeline_events or [])
        ],
        "assignments": [
            {
                "id": str(a.id),
                "volunteer_id": str(a.volunteer_id) if a.volunteer_id else None,
                "status": a.status,
                "assigned_at": a.assigned_at.isoformat() if a.assigned_at else None,
            }
            for a in (case.assignments or [])
        ],
    }


@router.patch("/{case_id}")
async def update_case(
    case_id: str,
    request: CaseUpdateRequest,
    current_user: dict = Depends(require_role("police", "admin")),
    db: AsyncSession = Depends(get_db)
):
    """Update case details (Police/Admin only)."""
    result = await db.execute(select(MissingPerson).where(MissingPerson.case_id == case_id))
    case = result.scalar_one_or_none()
    
    if not case:
        raise HTTPException(status_code=404, detail="Case not found")
    
    update_data = request.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(case, field, value)
    
    # Add timeline event
    timeline = TimelineEvent(
        case_id=case.id,
        event_type="updated",
        title="Case Updated",
        description=f"Case details updated by {current_user.get('name')}",
        actor_id=uuid.UUID(current_user["sub"]),
        actor_name=current_user.get("name"),
        meta=update_data,
    )
    db.add(timeline)
    
    return {"message": "Case updated successfully", "case_id": case_id}


@router.patch("/{case_id}/status")
async def update_case_status(
    case_id: str,
    request: StatusUpdateRequest,
    current_user: dict = Depends(require_role("police", "admin", "volunteer")),
    db: AsyncSession = Depends(get_db)
):
    """Update case status."""
    result = await db.execute(select(MissingPerson).where(MissingPerson.case_id == case_id))
    case = result.scalar_one_or_none()
    
    if not case:
        raise HTTPException(status_code=404, detail="Case not found")
    
    old_status = case.status
    case.status = request.status
    
    if request.status in ("Reunited", "Transferred to hospital", "Unresolved"):
        case.resolved_at = datetime.now(timezone.utc)
        if case.reported_at:
            delta = (case.resolved_at - case.reported_at).total_seconds() / 3600
            case.resolution_hours = round(delta, 1)
    
    # Timeline event
    timeline = TimelineEvent(
        case_id=case.id,
        event_type="status_changed",
        title=f"Status: {old_status} → {request.status}",
        description=request.notes or f"Status changed to {request.status}",
        actor_id=uuid.UUID(current_user["sub"]),
        actor_name=current_user.get("name"),
        meta={"old_status": old_status, "new_status": request.status},
    )
    db.add(timeline)
    
    return {"message": f"Status updated to {request.status}", "case_id": case_id}


@router.get("/{case_id}/timeline")
async def get_case_timeline(
    case_id: str,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get chronological timeline for a case."""
    # First get the case UUID
    case_result = await db.execute(select(MissingPerson.id).where(MissingPerson.case_id == case_id))
    case_uuid = case_result.scalar_one_or_none()
    if not case_uuid:
        raise HTTPException(status_code=404, detail="Case not found")
    
    result = await db.execute(
        select(TimelineEvent)
        .where(TimelineEvent.case_id == case_uuid)
        .order_by(TimelineEvent.created_at.asc())
    )
    events = result.scalars().all()
    
    return {
        "case_id": case_id,
        "events": [
            {
                "id": str(e.id),
                "event_type": e.event_type,
                "title": e.title,
                "description": e.description,
                "actor_name": e.actor_name,
                "created_at": e.created_at.isoformat(),
                "metadata": e.meta,
            }
            for e in events
        ]
    }


@router.post("/{case_id}/timeline")
async def add_timeline_event(
    case_id: str,
    request: TimelineEventRequest,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Add a timeline event to a case."""
    case_result = await db.execute(select(MissingPerson.id).where(MissingPerson.case_id == case_id))
    case_uuid = case_result.scalar_one_or_none()
    if not case_uuid:
        raise HTTPException(status_code=404, detail="Case not found")
    
    event = TimelineEvent(
        case_id=case_uuid,
        event_type=request.event_type,
        title=request.title,
        description=request.description,
        actor_id=uuid.UUID(current_user["sub"]),
        actor_name=current_user.get("name"),
        meta=request.metadata or {},
    )
    db.add(event)
    
    return {"message": "Timeline event added", "event_id": str(event.id)}


@router.get("/{case_id}/duplicates")
async def get_case_duplicates(
    case_id: str,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get duplicate case matches for a case."""
    case_result = await db.execute(select(MissingPerson.id).where(MissingPerson.case_id == case_id))
    case_uuid = case_result.scalar_one_or_none()
    if not case_uuid:
        raise HTTPException(status_code=404, detail="Case not found")
    
    result = await db.execute(
        select(DuplicateCase).where(
            or_(DuplicateCase.case_a_id == case_uuid, DuplicateCase.case_b_id == case_uuid)
        )
    )
    duplicates = result.scalars().all()
    
    return {
        "case_id": case_id,
        "duplicates": [
            {
                "id": str(d.id),
                "case_a_id": str(d.case_a_id),
                "case_b_id": str(d.case_b_id),
                "similarity_score": d.similarity_score,
                "match_type": d.match_type,
                "status": d.status,
            }
            for d in duplicates
        ]
    }


@router.post("/{case_id}/duplicates/{dup_id}/merge")
async def merge_duplicate(
    case_id: str,
    dup_id: str,
    current_user: dict = Depends(require_role("police", "admin")),
    db: AsyncSession = Depends(get_db)
):
    """Approve and merge a duplicate case (Police/Admin only)."""
    result = await db.execute(select(DuplicateCase).where(DuplicateCase.id == uuid.UUID(dup_id)))
    duplicate = result.scalar_one_or_none()
    if not duplicate:
        raise HTTPException(status_code=404, detail="Duplicate record not found")
    
    duplicate.status = "merged"
    duplicate.reviewed_by = uuid.UUID(current_user["sub"])
    duplicate.reviewed_at = datetime.now(timezone.utc)
    
    return {"message": "Duplicate cases merged", "duplicate_id": dup_id}


@router.post("/{case_id}/duplicates/{dup_id}/dismiss")
async def dismiss_duplicate(
    case_id: str,
    dup_id: str,
    current_user: dict = Depends(require_role("police", "admin")),
    db: AsyncSession = Depends(get_db)
):
    """Dismiss a duplicate case match (Police/Admin only)."""
    result = await db.execute(select(DuplicateCase).where(DuplicateCase.id == uuid.UUID(dup_id)))
    duplicate = result.scalar_one_or_none()
    if not duplicate:
        raise HTTPException(status_code=404, detail="Duplicate record not found")
    
    duplicate.status = "dismissed"
    duplicate.reviewed_by = uuid.UUID(current_user["sub"])
    duplicate.reviewed_at = datetime.now(timezone.utc)
    
    return {"message": "Duplicate dismissed", "duplicate_id": dup_id}
