"""
KumbhSathi AI — Backend Configuration
Environment-based settings with Pydantic BaseSettings
"""
from pydantic_settings import BaseSettings
from typing import List, Optional
import os


class Settings(BaseSettings):
    # ============================================================
    # Application
    # ============================================================
    APP_NAME: str = "KumbhSathi AI"
    APP_VERSION: str = "1.0.0"
    ENVIRONMENT: str = "development"
    DEBUG: bool = True
    
    # ============================================================
    # Database
    # ============================================================
    DATABASE_URL: str = "postgresql+asyncpg://kumbhsathi_user:kumbhsathi_secure_2027@localhost:5432/kumbhsathi"
    DATABASE_ECHO: bool = False
    
    # ============================================================
    # Redis
    # ============================================================
    REDIS_URL: str = "redis://localhost:6379/0"
    
    # ============================================================
    # JWT Authentication
    # ============================================================
    JWT_SECRET_KEY: str = "your-super-secret-key-change-in-production"
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRATION_MINUTES: int = 60
    JWT_REFRESH_EXPIRATION_DAYS: int = 7
    
    # ============================================================
    # CORS
    # ============================================================
    CORS_ORIGINS: List[str] = ["http://localhost:3000", "http://localhost:8080"]
    
    # ============================================================
    # File Uploads
    # ============================================================
    UPLOAD_DIR: str = "./uploads"
    MAX_UPLOAD_SIZE_MB: int = 10
    ALLOWED_IMAGE_TYPES: List[str] = ["image/jpeg", "image/png", "image/webp"]
    
    # ============================================================
    # AI / ML
    # ============================================================
    FACE_RECOGNITION_THRESHOLD: float = 0.6
    FACE_RECOGNITION_MODEL: str = "hog"  # hog (CPU) or cnn (GPU)
    DUPLICATE_SIMILARITY_THRESHOLD: float = 0.75
    PRIORITY_MODEL_PATH: str = "./ml_models/priority_model.joblib"
    ZONE_MODEL_PATH: str = "./ml_models/zone_predictor.joblib"
    EMBEDDING_MODEL_NAME: str = "all-MiniLM-L6-v2"
    
    # ============================================================
    # Aadhaar
    # ============================================================
    AADHAAR_HASH_SALT: str = "kumbhsathi-aadhaar-salt-change-in-production"
    AADHAAR_RECORD_EXPIRY_DAYS: int = 30
    
    # ============================================================
    # LLM (for AI Interview Agent)
    # ============================================================
    LLM_PROVIDER: str = "groq"  # gemini, openai, or groq
    GEMINI_API_KEY: Optional[str] = None
    OPENAI_API_KEY: Optional[str] = None
    GROQ_API_KEY: Optional[str] = None
    
    # ============================================================
    # CSV Data Paths
    # ============================================================
    CSV_MISSING_PERSONS: str = "./data/Synthetic_Missing_Persons_2500.csv"
    CSV_CCTV_LOCATIONS: str = "./data/CCTV_Locations.csv"
    CSV_POLICE_STATIONS: str = "./data/Police_Stations.csv"
    CSV_ZONE_BOUNDARIES: str = "./data/Zone_Boundaries.csv"
    CSV_CHOKEPOINTS: str = "./data/Chokepoints_Parking.csv"
    
    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()
