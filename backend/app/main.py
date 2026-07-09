"""
KumbhSathi AI — FastAPI Application Entry Point
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from contextlib import asynccontextmanager
import os

from app.core.config import settings
from app.api.v1 import auth, cases, volunteers, zones, users, notifications, analytics, map_data, face_recognition, aadhaar, admin


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application startup and shutdown events."""
    # Startup
    os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
    os.makedirs(os.path.join(settings.UPLOAD_DIR, "photos"), exist_ok=True)
    os.makedirs(os.path.join(settings.UPLOAD_DIR, "aadhaar"), exist_ok=True)
    print(f"🚀 {settings.APP_NAME} v{settings.APP_VERSION} starting...")
    print(f"📊 Environment: {settings.ENVIRONMENT}")
    yield
    # Shutdown
    print(f"👋 {settings.APP_NAME} shutting down...")


app = FastAPI(
    title=settings.APP_NAME,
    description="AI-powered Incident Management Platform for Missing Persons at Kumbh Mela",
    version=settings.APP_VERSION,
    lifespan=lifespan,
    docs_url="/api/docs",
    redoc_url="/api/redoc",
)

# ============================================================
# CORS Middleware
# ============================================================
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ============================================================
# Static Files (uploaded photos)
# ============================================================
if os.path.exists(settings.UPLOAD_DIR):
    app.mount("/uploads", StaticFiles(directory=settings.UPLOAD_DIR), name="uploads")

# ============================================================
# API Routers
# ============================================================
API_PREFIX = "/api/v1"

app.include_router(auth.router, prefix=f"{API_PREFIX}/auth", tags=["Authentication"])
app.include_router(cases.router, prefix=f"{API_PREFIX}/cases", tags=["Cases"])
app.include_router(volunteers.router, prefix=f"{API_PREFIX}/volunteers", tags=["Volunteers"])
app.include_router(zones.router, prefix=f"{API_PREFIX}/zones", tags=["Zones"])
app.include_router(users.router, prefix=f"{API_PREFIX}/users", tags=["Users"])
app.include_router(notifications.router, prefix=f"{API_PREFIX}/notifications", tags=["Notifications"])
app.include_router(analytics.router, prefix=f"{API_PREFIX}/analytics", tags=["Analytics"])
app.include_router(map_data.router, prefix=f"{API_PREFIX}/map", tags=["Map Data"])
app.include_router(face_recognition.router, prefix=f"{API_PREFIX}/face", tags=["Face Recognition"])
app.include_router(aadhaar.router, prefix=f"{API_PREFIX}/aadhaar", tags=["Aadhaar OCR"])
app.include_router(admin.router, prefix=f"{API_PREFIX}/admin", tags=["Admin"])


# ============================================================
# Health Check
# ============================================================
@app.get("/health", tags=["Health"])
async def health_check():
    return {
        "status": "healthy",
        "app": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "environment": settings.ENVIRONMENT,
    }
