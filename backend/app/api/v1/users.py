"""
KumbhSathi AI — Users API Routes
"""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from pydantic import BaseModel
from typing import Optional
import uuid

from app.core.database import get_db
from app.core.security import get_current_user, require_role, hash_password
from app.models.models import User, Role

router = APIRouter()


class UserCreate(BaseModel):
    full_name: str
    phone: str
    email: Optional[str] = None
    role: str
    password: str
    language_code: str = "en"


class UserUpdate(BaseModel):
    full_name: Optional[str] = None
    is_active: Optional[bool] = None
    role: Optional[str] = None
    language_code: Optional[str] = None


@router.get("")
async def list_users(
    role: Optional[str] = None,
    is_active: Optional[bool] = None,
    search: Optional[str] = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_user: dict = Depends(require_role("admin")),
    db: AsyncSession = Depends(get_db)
):
    """List all users (Admin only)."""
    query = select(User).join(Role, isouter=True)
    count_query = select(func.count(User.id))
    
    if role:
        query = query.where(Role.name == role)
        count_query = count_query.join(Role).where(Role.name == role)
    if is_active is not None:
        query = query.where(User.is_active == is_active)
        count_query = count_query.where(User.is_active == is_active)
    if search:
        query = query.where(User.full_name.ilike(f"%{search}%"))
        count_query = count_query.where(User.full_name.ilike(f"%{search}%"))
    
    total = (await db.execute(count_query)).scalar()
    query = query.order_by(User.created_at.desc()).offset((page - 1) * page_size).limit(page_size)
    result = await db.execute(query)
    users = result.scalars().all()
    
    user_list = []
    for u in users:
        role_result = await db.execute(select(Role).where(Role.id == u.role_id))
        r = role_result.scalar_one_or_none()
        user_list.append({
            "id": str(u.id),
            "full_name": u.full_name,
            "phone": u.phone,
            "email": u.email,
            "role": r.name if r else None,
            "language_code": u.language_code,
            "is_active": u.is_active,
            "is_verified": u.is_verified,
            "created_at": u.created_at.isoformat(),
        })
    
    return {"users": user_list, "total": total, "page": page}


@router.post("", status_code=201)
async def create_user(
    request: UserCreate,
    current_user: dict = Depends(require_role("admin")),
    db: AsyncSession = Depends(get_db)
):
    """Create a new user (Admin only)."""
    role_result = await db.execute(select(Role).where(Role.name == request.role))
    role = role_result.scalar_one_or_none()
    if not role:
        raise HTTPException(status_code=400, detail=f"Invalid role: {request.role}")
    
    user = User(
        full_name=request.full_name,
        phone=request.phone,
        email=request.email,
        hashed_password=hash_password(request.password),
        role_id=role.id,
        language_code=request.language_code,
        is_verified=True,
    )
    db.add(user)
    await db.flush()
    return {"message": "User created", "id": str(user.id)}


@router.patch("/{user_id}")
async def update_user(
    user_id: str,
    request: UserUpdate,
    current_user: dict = Depends(require_role("admin")),
    db: AsyncSession = Depends(get_db)
):
    """Update a user (Admin only)."""
    result = await db.execute(select(User).where(User.id == uuid.UUID(user_id)))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    update_data = request.model_dump(exclude_unset=True)
    if "role" in update_data:
        role_result = await db.execute(select(Role).where(Role.name == update_data.pop("role")))
        role = role_result.scalar_one_or_none()
        if role:
            user.role_id = role.id
    
    for field, value in update_data.items():
        setattr(user, field, value)
    
    return {"message": "User updated"}
