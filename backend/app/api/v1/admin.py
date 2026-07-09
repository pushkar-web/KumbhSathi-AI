"""
KumbhSathi AI — Admin API Routes (Audit Logs, Predictions)
"""
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from typing import Optional
import uuid

from app.core.database import get_db
from app.core.security import require_role
from app.models.models import AuditLog, Prediction

router = APIRouter()


@router.get("/audit-logs")
async def list_audit_logs(
    user_id: Optional[str] = None,
    action: Optional[str] = None,
    resource_type: Optional[str] = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
    current_user: dict = Depends(require_role("admin")),
    db: AsyncSession = Depends(get_db)
):
    """List audit logs (Admin only)."""
    query = select(AuditLog)
    count_query = select(func.count(AuditLog.id))
    
    if user_id:
        query = query.where(AuditLog.user_id == uuid.UUID(user_id))
        count_query = count_query.where(AuditLog.user_id == uuid.UUID(user_id))
    if action:
        query = query.where(AuditLog.action.ilike(f"%{action}%"))
        count_query = count_query.where(AuditLog.action.ilike(f"%{action}%"))
    if resource_type:
        query = query.where(AuditLog.resource_type == resource_type)
        count_query = count_query.where(AuditLog.resource_type == resource_type)
    
    total = (await db.execute(count_query)).scalar()
    query = query.order_by(AuditLog.created_at.desc()).offset((page - 1) * page_size).limit(page_size)
    result = await db.execute(query)
    logs = result.scalars().all()
    
    return {
        "audit_logs": [
            {
                "id": str(l.id),
                "user_id": str(l.user_id) if l.user_id else None,
                "action": l.action,
                "resource_type": l.resource_type,
                "resource_id": str(l.resource_id) if l.resource_id else None,
                "ip_address": l.ip_address,
                "created_at": l.created_at.isoformat(),
            }
            for l in logs
        ],
        "total": total,
        "page": page,
    }
