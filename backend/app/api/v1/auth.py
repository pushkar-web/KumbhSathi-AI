"""
KumbhSathi AI — Authentication API Routes
JWT login, registration, OTP verification, token refresh
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel, EmailStr, Field
from typing import Optional
from datetime import datetime, timezone
import uuid

from app.core.database import get_db
from app.core.security import (
    hash_password, verify_password, 
    create_access_token, create_refresh_token, decode_token,
    get_current_user
)
from app.models.models import User, Role

router = APIRouter()


# ============================================================
# Pydantic Schemas
# ============================================================
class RegisterRequest(BaseModel):
    full_name: str = Field(..., min_length=2, max_length=200)
    phone: str = Field(..., pattern=r'^\+91\d{10}$')
    email: Optional[EmailStr] = None
    password: str = Field(..., min_length=6)
    role: str = Field(..., pattern=r'^(family|police|volunteer|admin)$')
    language_code: str = Field(default="en")


class LoginRequest(BaseModel):
    phone: str = Field(..., description="Phone number with +91 prefix")
    password: str


class OTPSendRequest(BaseModel):
    phone: str = Field(..., pattern=r'^\+91\d{10}$')


class OTPVerifyRequest(BaseModel):
    phone: str
    otp: str = Field(..., min_length=6, max_length=6)


class RefreshRequest(BaseModel):
    refresh_token: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: dict


class UserResponse(BaseModel):
    id: str
    full_name: str
    phone: Optional[str]
    email: Optional[str]
    role: str
    language_code: str
    is_active: bool
    created_at: datetime


# ============================================================
# Routes
# ============================================================
@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def register(request: RegisterRequest, db: AsyncSession = Depends(get_db)):
    """Register a new user with role assignment."""
    # Check if phone already exists
    existing = await db.execute(select(User).where(User.phone == request.phone))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Phone number already registered")
    
    # Check if email already exists
    if request.email:
        existing_email = await db.execute(select(User).where(User.email == request.email))
        if existing_email.scalar_one_or_none():
            raise HTTPException(status_code=400, detail="Email already registered")
    
    # Get role
    role_result = await db.execute(select(Role).where(Role.name == request.role))
    role = role_result.scalar_one_or_none()
    if not role:
        raise HTTPException(status_code=400, detail=f"Invalid role: {request.role}")
    
    # Create user
    user = User(
        full_name=request.full_name,
        phone=request.phone,
        email=request.email,
        hashed_password=hash_password(request.password),
        role_id=role.id,
        language_code=request.language_code,
        is_verified=True,  # Auto-verify for MVP
    )
    db.add(user)
    await db.flush()
    
    # Generate tokens
    token_data = {"sub": str(user.id), "role": role.name, "name": user.full_name}
    access_token = create_access_token(token_data)
    refresh_token = create_refresh_token(token_data)
    
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        user={
            "id": str(user.id),
            "full_name": user.full_name,
            "phone": user.phone,
            "email": user.email,
            "role": role.name,
            "language_code": user.language_code,
        }
    )


@router.post("/login", response_model=TokenResponse)
async def login(request: LoginRequest, db: AsyncSession = Depends(get_db)):
    """Login with phone + password."""
    result = await db.execute(
        select(User).where(User.phone == request.phone)
    )
    user = result.scalar_one_or_none()
    
    if not user or not verify_password(request.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid phone number or password")
    
    if not user.is_active:
        raise HTTPException(status_code=403, detail="Account is deactivated")
    
    # Get role name
    role_result = await db.execute(select(Role).where(Role.id == user.role_id))
    role = role_result.scalar_one_or_none()
    role_name = role.name if role else "family"
    
    # Update last login
    user.last_login_at = datetime.now(timezone.utc)
    
    # Generate tokens
    token_data = {"sub": str(user.id), "role": role_name, "name": user.full_name}
    access_token = create_access_token(token_data)
    refresh_token = create_refresh_token(token_data)
    
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        user={
            "id": str(user.id),
            "full_name": user.full_name,
            "phone": user.phone,
            "email": user.email,
            "role": role_name,
            "language_code": user.language_code,
        }
    )


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(request: RefreshRequest, db: AsyncSession = Depends(get_db)):
    """Refresh access token using refresh token."""
    payload = decode_token(request.refresh_token)
    if payload.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="Invalid refresh token")
    
    user_id = payload.get("sub")
    result = await db.execute(select(User).where(User.id == uuid.UUID(user_id)))
    user = result.scalar_one_or_none()
    
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    
    role_result = await db.execute(select(Role).where(Role.id == user.role_id))
    role = role_result.scalar_one_or_none()
    role_name = role.name if role else "family"
    
    token_data = {"sub": str(user.id), "role": role_name, "name": user.full_name}
    access_token = create_access_token(token_data)
    new_refresh_token = create_refresh_token(token_data)
    
    return TokenResponse(
        access_token=access_token,
        refresh_token=new_refresh_token,
        user={
            "id": str(user.id),
            "full_name": user.full_name,
            "phone": user.phone,
            "email": user.email,
            "role": role_name,
            "language_code": user.language_code,
        }
    )


@router.post("/otp/send")
async def send_otp(request: OTPSendRequest):
    """Send OTP to phone number. (Simulated for development)"""
    # In production: integrate with SMS gateway (MSG91, Twilio, etc.)
    return {"message": "OTP sent successfully", "otp": "123456", "expires_in": 300}


@router.post("/otp/verify")
async def verify_otp(request: OTPVerifyRequest, db: AsyncSession = Depends(get_db)):
    """Verify OTP and return tokens. (Simulated for development)"""
    # In production: verify against stored OTP
    if request.otp != "123456":
        raise HTTPException(status_code=401, detail="Invalid OTP")
    
    result = await db.execute(select(User).where(User.phone == request.phone))
    user = result.scalar_one_or_none()
    
    if not user:
        raise HTTPException(status_code=404, detail="User not found. Please register first.")
    
    role_result = await db.execute(select(Role).where(Role.id == user.role_id))
    role = role_result.scalar_one_or_none()
    role_name = role.name if role else "family"
    
    token_data = {"sub": str(user.id), "role": role_name, "name": user.full_name}
    access_token = create_access_token(token_data)
    refresh_token = create_refresh_token(token_data)
    
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        user={
            "id": str(user.id),
            "full_name": user.full_name,
            "phone": user.phone,
            "role": role_name,
            "language_code": user.language_code,
        }
    )


@router.get("/me")
async def get_current_user_profile(
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get current authenticated user profile."""
    result = await db.execute(select(User).where(User.id == uuid.UUID(current_user["sub"])))
    user = result.scalar_one_or_none()
    
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    return {
        "id": str(user.id),
        "full_name": user.full_name,
        "phone": user.phone,
        "email": user.email,
        "role": current_user.get("role"),
        "language_code": user.language_code,
        "is_active": user.is_active,
        "is_verified": user.is_verified,
        "created_at": user.created_at.isoformat(),
    }
