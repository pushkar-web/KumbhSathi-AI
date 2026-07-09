"""
KumbhSathi AI — SQLAlchemy ORM Models
All 19 tables mapped to Python classes
"""
import uuid
from datetime import datetime, timezone
from sqlalchemy import (
    Column, String, Boolean, Integer, Float, Text, DateTime, 
    ForeignKey, UniqueConstraint, Index, Enum as SQLEnum
)
from sqlalchemy.dialects.postgresql import UUID, JSONB, ARRAY
from sqlalchemy.orm import relationship
from pgvector.sqlalchemy import Vector
from geoalchemy2 import Geometry

from app.core.database import Base


def utcnow():
    return datetime.now(timezone.utc)


# ============================================================
# Languages
# ============================================================
class Language(Base):
    __tablename__ = "languages"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    code = Column(String(10), unique=True, nullable=False)
    name = Column(String(50), nullable=False)
    native_name = Column(String(50))
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), default=utcnow)


# ============================================================
# Roles
# ============================================================
class Role(Base):
    __tablename__ = "roles"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(30), unique=True, nullable=False)
    display_name = Column(String(50), nullable=False)
    permissions = Column(JSONB, default={})
    description = Column(Text)
    created_at = Column(DateTime(timezone=True), default=utcnow)
    
    users = relationship("User", back_populates="role")


# ============================================================
# Users
# ============================================================
class User(Base):
    __tablename__ = "users"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(String(255), unique=True, index=True)
    phone = Column(String(20), unique=True, index=True)
    hashed_password = Column(String(255), nullable=False)
    full_name = Column(String(200), nullable=False)
    role_id = Column(UUID(as_uuid=True), ForeignKey("roles.id", ondelete="SET NULL"))
    language_code = Column(String(10), default="en")
    avatar_url = Column(Text)
    is_active = Column(Boolean, default=True)
    is_verified = Column(Boolean, default=False)
    last_login_at = Column(DateTime(timezone=True))
    created_at = Column(DateTime(timezone=True), default=utcnow)
    updated_at = Column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)
    
    role = relationship("Role", back_populates="users")
    volunteer_profile = relationship("Volunteer", back_populates="user", uselist=False)
    reported_cases = relationship("MissingPerson", back_populates="reporter", foreign_keys="MissingPerson.reporter_id")


# ============================================================
# Zones (from Zone_Boundaries.csv)
# ============================================================
class Zone(Base):
    __tablename__ = "zones"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    zone_name = Column(String(100), nullable=False)
    centroid = Column(Geometry("POINT", srid=4326))
    centroid_lat = Column(Float, nullable=False)
    centroid_lng = Column(Float, nullable=False)
    boundary = Column(Geometry("POLYGON", srid=4326))
    approx_boundary_pts = Column(Integer)
    crowd_density = Column(String(20), default="medium")
    risk_level = Column(String(20), default="normal")
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), default=utcnow)
    updated_at = Column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)
    
    cctv_cameras = relationship("CCTVLocation", back_populates="zone")
    cases = relationship("MissingPerson", back_populates="last_seen_zone")


# ============================================================
# Police Stations (from Police_Stations.csv)
# ============================================================
class PoliceStation(Base):
    __tablename__ = "police_stations"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    station_name = Column(String(200), nullable=False)
    location = Column(Geometry("POINT", srid=4326))
    longitude = Column(Float, nullable=False)
    latitude = Column(Float, nullable=False)
    jurisdiction = Column(Geometry("POLYGON", srid=4326))
    phone = Column(String(20))
    officer_count = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), default=utcnow)


# ============================================================
# CCTV Locations (from CCTV_Locations.csv)
# ============================================================
class CCTVLocation(Base):
    __tablename__ = "cctv_locations"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    camera_id = Column(String(20), unique=True, nullable=False)
    location = Column(Geometry("POINT", srid=4326))
    longitude = Column(Float, nullable=False)
    latitude = Column(Float, nullable=False)
    zone_id = Column(UUID(as_uuid=True), ForeignKey("zones.id", ondelete="SET NULL"))
    status = Column(String(20), default="active")
    coverage_angle = Column(Float)
    created_at = Column(DateTime(timezone=True), default=utcnow)
    
    zone = relationship("Zone", back_populates="cctv_cameras")


# ============================================================
# Chokepoints & Parking (from Chokepoints_Parking.csv)
# ============================================================
class Chokepoint(Base):
    __tablename__ = "chokepoints"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    location_name = Column(String(200), nullable=False)
    category = Column(String(50), nullable=False)
    location = Column(Geometry("POINT", srid=4326))
    longitude = Column(Float, nullable=False)
    latitude = Column(Float, nullable=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), default=utcnow)


# ============================================================
# Medical Conditions
# ============================================================
class MedicalCondition(Base):
    __tablename__ = "medical_conditions"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(100), nullable=False)
    severity = Column(String(20), nullable=False)
    description = Column(Text)
    created_at = Column(DateTime(timezone=True), default=utcnow)


# ============================================================
# Missing Persons (from Synthetic_Missing_Persons_2500.csv)
# ============================================================
class MissingPerson(Base):
    __tablename__ = "missing_persons"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    case_id = Column(String(20), unique=True, nullable=False, index=True)
    reporter_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"))
    
    # Person Details
    missing_person_name = Column(String(200))
    gender = Column(String(20))
    age_band = Column(String(10))
    state = Column(String(100))
    district = Column(String(100))
    language = Column(String(50))
    
    # Description
    physical_description = Column(Text)
    clothing_description = Column(Text)
    photo_url = Column(Text)
    unique_identifiers = Column(Text)
    
    # Location
    last_seen_location = Column(String(200))
    last_seen_lat = Column(Float)
    last_seen_lng = Column(Float)
    last_seen_point = Column(Geometry("POINT", srid=4326))
    last_seen_zone_id = Column(UUID(as_uuid=True), ForeignKey("zones.id", ondelete="SET NULL"))
    
    # Status & Priority
    status = Column(String(30), nullable=False, default="Pending", index=True)
    priority = Column(String(20), default="Medium", index=True)
    priority_score = Column(Float)
    
    # Reporting
    reported_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    reporting_center = Column(String(200))
    reporter_mobile = Column(String(20))
    
    # Resolution
    resolution_hours = Column(Float)
    resolved_at = Column(DateTime(timezone=True))
    
    # Flags
    is_duplicate_report = Column(Boolean, default=False)
    
    # AI Data
    ai_extracted_data = Column(JSONB, default={})
    
    # Metadata
    remarks = Column(Text)
    created_at = Column(DateTime(timezone=True), default=utcnow)
    updated_at = Column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)
    
    # Relationships
    reporter = relationship("User", back_populates="reported_cases", foreign_keys=[reporter_id])
    last_seen_zone = relationship("Zone", back_populates="cases")
    reports = relationship("Report", back_populates="missing_person")
    timeline_events = relationship("TimelineEvent", back_populates="case", order_by="TimelineEvent.created_at")
    assignments = relationship("Assignment", back_populates="case")
    predictions = relationship("Prediction", back_populates="case")
    face_embeddings = relationship("FaceEmbedding", back_populates="missing_person")
    aadhaar_records = relationship("AadhaarRecord", back_populates="missing_person", foreign_keys="AadhaarRecord.missing_person_id")


# ============================================================
# Reports
# ============================================================
class Report(Base):
    __tablename__ = "reports"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    missing_person_id = Column(UUID(as_uuid=True), ForeignKey("missing_persons.id", ondelete="CASCADE"))
    reporter_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"))
    source = Column(String(30), nullable=False, default="text")
    raw_input = Column(Text)
    ai_processed_data = Column(JSONB, default={})
    language = Column(String(50))
    created_at = Column(DateTime(timezone=True), default=utcnow)
    
    missing_person = relationship("MissingPerson", back_populates="reports")


# ============================================================
# Volunteers
# ============================================================
class Volunteer(Base):
    __tablename__ = "volunteers"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), unique=True)
    current_location = Column(Geometry("POINT", srid=4326))
    current_lat = Column(Float)
    current_lng = Column(Float)
    is_available = Column(Boolean, default=True)
    languages = Column(ARRAY(Text), default=[])
    skills = Column(ARRAY(Text), default=[])
    current_workload = Column(Integer, default=0)
    max_workload = Column(Integer, default=5)
    assigned_zone_id = Column(UUID(as_uuid=True), ForeignKey("zones.id"))
    created_at = Column(DateTime(timezone=True), default=utcnow)
    updated_at = Column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)
    
    user = relationship("User", back_populates="volunteer_profile")
    assignments = relationship("Assignment", back_populates="volunteer")


# ============================================================
# Assignments
# ============================================================
class Assignment(Base):
    __tablename__ = "assignments"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    case_id = Column(UUID(as_uuid=True), ForeignKey("missing_persons.id", ondelete="CASCADE"))
    volunteer_id = Column(UUID(as_uuid=True), ForeignKey("volunteers.id", ondelete="SET NULL"))
    status = Column(String(30), nullable=False, default="assigned")
    priority = Column(String(20))
    notes = Column(Text)
    assigned_at = Column(DateTime(timezone=True), default=utcnow)
    accepted_at = Column(DateTime(timezone=True))
    completed_at = Column(DateTime(timezone=True))
    created_by = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    
    case = relationship("MissingPerson", back_populates="assignments")
    volunteer = relationship("Volunteer", back_populates="assignments")


# ============================================================
# Notifications
# ============================================================
class Notification(Base):
    __tablename__ = "notifications"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"))
    case_id = Column(UUID(as_uuid=True), ForeignKey("missing_persons.id", ondelete="SET NULL"))
    type = Column(String(50), nullable=False)
    title = Column(String(200))
    message = Column(Text, nullable=False)
    language = Column(String(50), default="en")
    is_read = Column(Boolean, default=False)
    priority = Column(String(20), default="normal")
    # NOTE: "metadata" is reserved by SQLAlchemy's declarative API; map to a
    # differently-named Python attribute while keeping the DB column "metadata".
    meta = Column("metadata", JSONB, default={})
    created_at = Column(DateTime(timezone=True), default=utcnow)


# ============================================================
# Timeline Events
# ============================================================
class TimelineEvent(Base):
    __tablename__ = "timeline_events"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    case_id = Column(UUID(as_uuid=True), ForeignKey("missing_persons.id", ondelete="CASCADE"))
    event_type = Column(String(50), nullable=False)
    title = Column(String(200))
    description = Column(Text)
    actor_id = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    actor_name = Column(String(200))
    # See note in Notification: avoid the reserved "metadata" attribute name.
    meta = Column("metadata", JSONB, default={})
    created_at = Column(DateTime(timezone=True), default=utcnow)

    case = relationship("MissingPerson", back_populates="timeline_events")


# ============================================================
# Predictions
# ============================================================
class Prediction(Base):
    __tablename__ = "predictions"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    case_id = Column(UUID(as_uuid=True), ForeignKey("missing_persons.id", ondelete="CASCADE"))
    prediction_type = Column(String(50), nullable=False)
    data = Column(JSONB, nullable=False)
    confidence = Column(Float)
    model_version = Column(String(50))
    created_at = Column(DateTime(timezone=True), default=utcnow)
    
    case = relationship("MissingPerson", back_populates="predictions")


# ============================================================
# Duplicate Cases
# ============================================================
class DuplicateCase(Base):
    __tablename__ = "duplicate_cases"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    case_a_id = Column(UUID(as_uuid=True), ForeignKey("missing_persons.id", ondelete="CASCADE"))
    case_b_id = Column(UUID(as_uuid=True), ForeignKey("missing_persons.id", ondelete="CASCADE"))
    similarity_score = Column(Float, nullable=False)
    match_type = Column(String(30), default="text")
    status = Column(String(20), default="pending")
    reviewed_by = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    reviewed_at = Column(DateTime(timezone=True))
    created_at = Column(DateTime(timezone=True), default=utcnow)
    
    __table_args__ = (UniqueConstraint("case_a_id", "case_b_id"),)


# ============================================================
# Audit Logs
# ============================================================
class AuditLog(Base):
    __tablename__ = "audit_logs"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"))
    action = Column(String(100), nullable=False)
    resource_type = Column(String(50))
    resource_id = Column(UUID(as_uuid=True))
    old_data = Column(JSONB)
    new_data = Column(JSONB)
    ip_address = Column(String(45))
    user_agent = Column(Text)
    created_at = Column(DateTime(timezone=True), default=utcnow)


# ============================================================
# Face Embeddings (pgvector)
# ============================================================
class FaceEmbedding(Base):
    __tablename__ = "face_embeddings"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    missing_person_id = Column(UUID(as_uuid=True), ForeignKey("missing_persons.id", ondelete="CASCADE"))
    embedding = Column(Vector(128), nullable=False)
    photo_url = Column(Text, nullable=False)
    source = Column(String(30), nullable=False, default="reporter")
    quality_score = Column(Float)
    num_faces_detected = Column(Integer, default=1)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), default=utcnow)
    created_by = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    
    missing_person = relationship("MissingPerson", back_populates="face_embeddings")


# ============================================================
# Aadhaar Records (privacy-first)
# ============================================================
class AadhaarRecord(Base):
    __tablename__ = "aadhaar_records"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    missing_person_id = Column(UUID(as_uuid=True), ForeignKey("missing_persons.id", ondelete="SET NULL"))
    aadhaar_hash = Column(String(64), nullable=False, index=True)
    name_extracted = Column(String(200))
    dob_extracted = Column(DateTime)
    gender_extracted = Column(String(20))
    address_extracted = Column(Text)
    state_extracted = Column(String(100))
    district_extracted = Column(String(100))
    raw_ocr_confidence = Column(Float)
    match_status = Column(String(20), default="pending")
    matched_person_id = Column(UUID(as_uuid=True), ForeignKey("missing_persons.id"))
    created_at = Column(DateTime(timezone=True), default=utcnow)
    created_by = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    
    missing_person = relationship("MissingPerson", back_populates="aadhaar_records", foreign_keys=[missing_person_id])
