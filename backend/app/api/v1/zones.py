"""
KumbhSathi AI — Zones API Routes
"""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel
from typing import Optional
import uuid

from app.core.database import get_db
from app.core.security import get_current_user, require_role
from app.models.models import Zone

router = APIRouter()


class ZoneCreate(BaseModel):
    zone_name: str
    centroid_lat: float
    centroid_lng: float
    approx_boundary_pts: Optional[int] = None
    crowd_density: Optional[str] = "medium"
    risk_level: Optional[str] = "normal"


class ZoneUpdate(BaseModel):
    crowd_density: Optional[str] = None
    risk_level: Optional[str] = None
    is_active: Optional[bool] = None


@router.get("")
async def list_zones(
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """List all zones."""
    result = await db.execute(select(Zone).where(Zone.is_active == True).order_by(Zone.zone_name))
    zones = result.scalars().all()
    return {
        "zones": [
            {
                "id": str(z.id),
                "zone_name": z.zone_name,
                "centroid_lat": z.centroid_lat,
                "centroid_lng": z.centroid_lng,
                "approx_boundary_pts": z.approx_boundary_pts,
                "crowd_density": z.crowd_density,
                "risk_level": z.risk_level,
            }
            for z in zones
        ]
    }


@router.post("", status_code=201)
async def create_zone(
    request: ZoneCreate,
    current_user: dict = Depends(require_role("admin")),
    db: AsyncSession = Depends(get_db)
):
    """Create a new zone (Admin only)."""
    zone = Zone(
        zone_name=request.zone_name,
        centroid_lat=request.centroid_lat,
        centroid_lng=request.centroid_lng,
        approx_boundary_pts=request.approx_boundary_pts,
        crowd_density=request.crowd_density,
        risk_level=request.risk_level,
    )
    db.add(zone)
    await db.flush()
    return {"message": "Zone created", "id": str(zone.id)}


@router.patch("/{zone_id}")
async def update_zone(
    zone_id: str,
    request: ZoneUpdate,
    current_user: dict = Depends(require_role("police", "admin")),
    db: AsyncSession = Depends(get_db)
):
    """Update zone properties."""
    result = await db.execute(select(Zone).where(Zone.id == uuid.UUID(zone_id)))
    zone = result.scalar_one_or_none()
    if not zone:
        raise HTTPException(status_code=404, detail="Zone not found")
    
    for field, value in request.model_dump(exclude_unset=True).items():
        setattr(zone, field, value)
    
    return {"message": "Zone updated"}
