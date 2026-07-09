"""
KumbhSathi AI — Analytics API Routes
Dashboard KPIs, heatmap data, trends — all computed from CSV-seeded data
"""
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, case, extract
from typing import Optional

from app.core.database import get_db
from app.core.security import get_current_user, require_role
from app.models.models import MissingPerson, Volunteer, Assignment, Zone

router = APIRouter()


@router.get("/dashboard")
async def get_dashboard_kpis(
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get dashboard KPIs."""
    # Total cases
    total = (await db.execute(select(func.count(MissingPerson.id)))).scalar() or 0
    
    # Status counts
    status_counts = {}
    for s in ["Pending", "Searching", "Reunited", "Transferred to hospital", "Unresolved"]:
        count = (await db.execute(
            select(func.count(MissingPerson.id)).where(MissingPerson.status == s)
        )).scalar() or 0
        status_counts[s] = count
    
    # Priority counts
    priority_counts = {}
    for p in ["Low", "Medium", "High", "Critical"]:
        count = (await db.execute(
            select(func.count(MissingPerson.id)).where(MissingPerson.priority == p)
        )).scalar() or 0
        priority_counts[p] = count
    
    # Average resolution hours
    avg_hours = (await db.execute(
        select(func.avg(MissingPerson.resolution_hours))
        .where(MissingPerson.resolution_hours.isnot(None))
    )).scalar() or 0
    
    # Children cases (0-12, 13-17) pending
    children_pending = (await db.execute(
        select(func.count(MissingPerson.id))
        .where(MissingPerson.age_band.in_(["0-12", "13-17"]))
        .where(MissingPerson.status == "Pending")
    )).scalar() or 0
    
    # Senior cases (71-80, 80+) pending
    senior_pending = (await db.execute(
        select(func.count(MissingPerson.id))
        .where(MissingPerson.age_band.in_(["71-80", "80+"]))
        .where(MissingPerson.status == "Pending")
    )).scalar() or 0
    
    # Duplicate rate
    duplicates = (await db.execute(
        select(func.count(MissingPerson.id))
        .where(MissingPerson.is_duplicate_report == True)
    )).scalar() or 0
    
    # Available volunteers
    available_volunteers = (await db.execute(
        select(func.count(Volunteer.id)).where(Volunteer.is_available == True)
    )).scalar() or 0
    
    return {
        "total_cases": total,
        "status_counts": status_counts,
        "priority_counts": priority_counts,
        "avg_resolution_hours": round(float(avg_hours), 1),
        "children_pending": children_pending,
        "senior_pending": senior_pending,
        "duplicate_count": duplicates,
        "duplicate_rate": round(duplicates / total * 100, 1) if total > 0 else 0,
        "available_volunteers": available_volunteers,
    }


@router.get("/heatmap")
async def get_heatmap_data(
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get case density by location for heatmap rendering."""
    result = await db.execute(
        select(
            MissingPerson.last_seen_location,
            func.count(MissingPerson.id).label("count")
        )
        .where(MissingPerson.last_seen_location.isnot(None))
        .group_by(MissingPerson.last_seen_location)
        .order_by(func.count(MissingPerson.id).desc())
    )
    locations = result.all()
    
    return {
        "heatmap": [
            {"location": loc, "count": count}
            for loc, count in locations
        ]
    }


@router.get("/trends")
async def get_trend_data(
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get trend data for charts."""
    # Cases by age band
    age_result = await db.execute(
        select(MissingPerson.age_band, func.count(MissingPerson.id))
        .where(MissingPerson.age_band.isnot(None))
        .group_by(MissingPerson.age_band)
    )
    age_distribution = [{"age_band": ab, "count": c} for ab, c in age_result.all()]
    
    # Cases by language
    lang_result = await db.execute(
        select(MissingPerson.language, func.count(MissingPerson.id))
        .where(MissingPerson.language.isnot(None))
        .group_by(MissingPerson.language)
        .order_by(func.count(MissingPerson.id).desc())
    )
    language_distribution = [{"language": l, "count": c} for l, c in lang_result.all()]
    
    # Cases by state
    state_result = await db.execute(
        select(MissingPerson.state, func.count(MissingPerson.id))
        .where(MissingPerson.state.isnot(None))
        .group_by(MissingPerson.state)
        .order_by(func.count(MissingPerson.id).desc())
        .limit(15)
    )
    state_distribution = [{"state": s, "count": c} for s, c in state_result.all()]
    
    # Cases by reporting center
    center_result = await db.execute(
        select(MissingPerson.reporting_center, func.count(MissingPerson.id))
        .where(MissingPerson.reporting_center.isnot(None))
        .group_by(MissingPerson.reporting_center)
        .order_by(func.count(MissingPerson.id).desc())
    )
    center_distribution = [{"center": c, "count": cnt} for c, cnt in center_result.all()]
    
    # Resolution time distribution
    res_result = await db.execute(
        select(
            case(
                (MissingPerson.resolution_hours <= 1, "0-1h"),
                (MissingPerson.resolution_hours <= 3, "1-3h"),
                (MissingPerson.resolution_hours <= 6, "3-6h"),
                (MissingPerson.resolution_hours <= 12, "6-12h"),
                (MissingPerson.resolution_hours <= 24, "12-24h"),
                else_="24h+"
            ).label("bucket"),
            func.count(MissingPerson.id)
        )
        .where(MissingPerson.resolution_hours.isnot(None))
        .group_by("bucket")
    )
    resolution_distribution = [{"bucket": b, "count": c} for b, c in res_result.all()]
    
    return {
        "age_distribution": age_distribution,
        "language_distribution": language_distribution,
        "state_distribution": state_distribution,
        "center_distribution": center_distribution,
        "resolution_distribution": resolution_distribution,
    }
