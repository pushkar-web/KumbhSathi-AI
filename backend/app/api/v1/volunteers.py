"""
KumbhSathi AI — Volunteers API Routes
"""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from pydantic import BaseModel
from typing import Optional
from datetime import datetime, timezone
import uuid

from app.core.database import get_db
from app.core.security import get_current_user, require_role
from app.models.models import Volunteer, Assignment, MissingPerson, User

router = APIRouter()


class AvailabilityUpdate(BaseModel):
    is_available: bool


class LocationUpdate(BaseModel):
    latitude: float
    longitude: float


class AssignmentCreate(BaseModel):
    case_id: str
    volunteer_id: str
    notes: Optional[str] = None


class AssignmentUpdate(BaseModel):
    status: str
    notes: Optional[str] = None


@router.get("")
async def list_volunteers(
    is_available: Optional[bool] = None,
    zone_id: Optional[str] = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_user: dict = Depends(require_role("police", "admin")),
    db: AsyncSession = Depends(get_db)
):
    """List all volunteers with filtering."""
    query = select(Volunteer).join(User)
    
    if is_available is not None:
        query = query.where(Volunteer.is_available == is_available)
    if zone_id:
        query = query.where(Volunteer.assigned_zone_id == uuid.UUID(zone_id))
    
    count_q = select(func.count(Volunteer.id))
    total = (await db.execute(count_q)).scalar()
    
    query = query.offset((page - 1) * page_size).limit(page_size)
    result = await db.execute(query)
    volunteers = result.scalars().all()
    
    vol_list = []
    for v in volunteers:
        user_result = await db.execute(select(User).where(User.id == v.user_id))
        user = user_result.scalar_one_or_none()
        vol_list.append({
            "id": str(v.id),
            "user_id": str(v.user_id),
            "name": user.full_name if user else "Unknown",
            "phone": user.phone if user else None,
            "is_available": v.is_available,
            "current_lat": v.current_lat,
            "current_lng": v.current_lng,
            "languages": v.languages or [],
            "current_workload": v.current_workload,
            "max_workload": v.max_workload,
        })
    
    return {"volunteers": vol_list, "total": total, "page": page}


@router.patch("/{volunteer_id}/availability")
async def toggle_availability(
    volunteer_id: str,
    request: AvailabilityUpdate,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Toggle volunteer availability."""
    result = await db.execute(select(Volunteer).where(Volunteer.id == uuid.UUID(volunteer_id)))
    volunteer = result.scalar_one_or_none()
    if not volunteer:
        raise HTTPException(status_code=404, detail="Volunteer not found")
    
    volunteer.is_available = request.is_available
    return {"message": f"Availability set to {request.is_available}", "volunteer_id": volunteer_id}


@router.patch("/{volunteer_id}/location")
async def update_location(
    volunteer_id: str,
    request: LocationUpdate,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Update volunteer's current location."""
    result = await db.execute(select(Volunteer).where(Volunteer.id == uuid.UUID(volunteer_id)))
    volunteer = result.scalar_one_or_none()
    if not volunteer:
        raise HTTPException(status_code=404, detail="Volunteer not found")
    
    volunteer.current_lat = request.latitude
    volunteer.current_lng = request.longitude
    return {"message": "Location updated"}


@router.get("/{volunteer_id}/assignments")
async def get_volunteer_assignments(
    volunteer_id: str,
    status: Optional[str] = None,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get assignments for a volunteer."""
    query = select(Assignment).where(Assignment.volunteer_id == uuid.UUID(volunteer_id))
    if status:
        query = query.where(Assignment.status == status)
    query = query.order_by(Assignment.assigned_at.desc())
    
    result = await db.execute(query)
    assignments = result.scalars().all()
    
    assignment_list = []
    for a in assignments:
        case_result = await db.execute(select(MissingPerson).where(MissingPerson.id == a.case_id))
        case = case_result.scalar_one_or_none()
        assignment_list.append({
            "id": str(a.id),
            "case_id": case.case_id if case else None,
            "case_name": case.missing_person_name if case else None,
            "case_status": case.status if case else None,
            "status": a.status,
            "priority": a.priority,
            "assigned_at": a.assigned_at.isoformat() if a.assigned_at else None,
            "notes": a.notes,
        })
    
    return {"assignments": assignment_list}


@router.post("/assignments", status_code=201)
async def create_assignment(
    request: AssignmentCreate,
    current_user: dict = Depends(require_role("police", "admin")),
    db: AsyncSession = Depends(get_db)
):
    """Assign a volunteer to a case."""
    case_result = await db.execute(select(MissingPerson).where(MissingPerson.case_id == request.case_id))
    case = case_result.scalar_one_or_none()
    if not case:
        raise HTTPException(status_code=404, detail="Case not found")
    
    assignment = Assignment(
        case_id=case.id,
        volunteer_id=uuid.UUID(request.volunteer_id),
        status="assigned",
        priority=case.priority,
        notes=request.notes,
        created_by=uuid.UUID(current_user["sub"]),
    )
    db.add(assignment)
    
    # Update volunteer workload
    vol_result = await db.execute(select(Volunteer).where(Volunteer.id == uuid.UUID(request.volunteer_id)))
    volunteer = vol_result.scalar_one_or_none()
    if volunteer:
        volunteer.current_workload = (volunteer.current_workload or 0) + 1
    
    return {"message": "Volunteer assigned", "assignment_id": str(assignment.id)}


@router.patch("/assignments/{assignment_id}")
async def update_assignment(
    assignment_id: str,
    request: AssignmentUpdate,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Update assignment status."""
    result = await db.execute(select(Assignment).where(Assignment.id == uuid.UUID(assignment_id)))
    assignment = result.scalar_one_or_none()
    if not assignment:
        raise HTTPException(status_code=404, detail="Assignment not found")
    
    assignment.status = request.status
    assignment.notes = request.notes
    
    if request.status == "completed":
        assignment.completed_at = datetime.now(timezone.utc)
        vol_result = await db.execute(select(Volunteer).where(Volunteer.id == assignment.volunteer_id))
        volunteer = vol_result.scalar_one_or_none()
        if volunteer and volunteer.current_workload > 0:
            volunteer.current_workload -= 1
    elif request.status == "accepted":
        assignment.accepted_at = datetime.now(timezone.utc)
    
    return {"message": f"Assignment status updated to {request.status}"}
