"""
KumbhSathi AI — Map Data API Routes
Serves CCTV, Police Stations, Chokepoints, and Zone geo data from CSV
"""
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.models import CCTVLocation, PoliceStation, Chokepoint, Zone

router = APIRouter()


@router.get("/cctv")
async def get_cctv_locations(
    zone_id: str = None,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get all 1,280 CCTV camera locations."""
    query = select(CCTVLocation)
    if zone_id:
        import uuid
        query = query.where(CCTVLocation.zone_id == uuid.UUID(zone_id))
    
    result = await db.execute(query)
    cameras = result.scalars().all()
    
    return {
        "cameras": [
            {
                "id": str(c.id),
                "camera_id": c.camera_id,
                "longitude": c.longitude,
                "latitude": c.latitude,
                "zone_id": str(c.zone_id) if c.zone_id else None,
                "status": c.status,
            }
            for c in cameras
        ],
        "total": len(cameras),
    }


@router.get("/police-stations")
async def get_police_stations(
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get all 14 police station locations."""
    result = await db.execute(select(PoliceStation).where(PoliceStation.is_active == True))
    stations = result.scalars().all()
    
    return {
        "stations": [
            {
                "id": str(s.id),
                "station_name": s.station_name,
                "longitude": s.longitude,
                "latitude": s.latitude,
                "phone": s.phone,
                "officer_count": s.officer_count,
            }
            for s in stations
        ]
    }


@router.get("/chokepoints")
async def get_chokepoints(
    category: str = None,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get all 85 chokepoints and parking locations."""
    query = select(Chokepoint).where(Chokepoint.is_active == True)
    if category:
        query = query.where(Chokepoint.category == category)
    
    result = await db.execute(query)
    points = result.scalars().all()
    
    return {
        "chokepoints": [
            {
                "id": str(p.id),
                "location_name": p.location_name,
                "category": p.category,
                "longitude": p.longitude,
                "latitude": p.latitude,
            }
            for p in points
        ]
    }


@router.get("/zones")
async def get_zones_geo(
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get all 32 zone boundaries for map rendering."""
    result = await db.execute(select(Zone).where(Zone.is_active == True))
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
