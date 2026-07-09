"""
KumbhSathi AI — Notifications API Routes
"""
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
import uuid

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.models import Notification

router = APIRouter()


@router.get("")
async def list_notifications(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    unread_only: bool = False,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get notifications for the current user."""
    user_id = uuid.UUID(current_user["sub"])
    query = select(Notification).where(Notification.user_id == user_id)
    count_query = select(func.count(Notification.id)).where(Notification.user_id == user_id)
    
    if unread_only:
        query = query.where(Notification.is_read == False)
        count_query = count_query.where(Notification.is_read == False)
    
    total = (await db.execute(count_query)).scalar()
    
    query = query.order_by(Notification.created_at.desc()).offset((page - 1) * page_size).limit(page_size)
    result = await db.execute(query)
    notifications = result.scalars().all()
    
    return {
        "notifications": [
            {
                "id": str(n.id),
                "type": n.type,
                "title": n.title,
                "message": n.message,
                "is_read": n.is_read,
                "priority": n.priority,
                "case_id": str(n.case_id) if n.case_id else None,
                "created_at": n.created_at.isoformat(),
            }
            for n in notifications
        ],
        "total": total,
        "unread_count": total if unread_only else None,
    }


@router.patch("/{notification_id}/read")
async def mark_as_read(
    notification_id: str,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Mark a notification as read."""
    result = await db.execute(select(Notification).where(Notification.id == uuid.UUID(notification_id)))
    notification = result.scalar_one_or_none()
    if notification:
        notification.is_read = True
    return {"message": "Notification marked as read"}
