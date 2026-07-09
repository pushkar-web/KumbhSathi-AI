-- ============================================================
-- KumbhSathi AI — Database Schema
-- PostgreSQL 16 + PostGIS + pgvector
-- 19 Tables for Incident Management Platform
-- ============================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";
CREATE EXTENSION IF NOT EXISTS "vector";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";  -- For fuzzy text matching

-- ============================================================
-- 1. LANGUAGES (from CSV: 10 unique languages)
-- ============================================================
CREATE TABLE languages (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code        VARCHAR(10) UNIQUE NOT NULL,
    name        VARCHAR(50) NOT NULL,
    native_name VARCHAR(50),
    is_active   BOOLEAN DEFAULT TRUE,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 2. ROLES (Static: FAMILY, POLICE, VOLUNTEER, ADMIN)
-- ============================================================
CREATE TABLE roles (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        VARCHAR(30) UNIQUE NOT NULL,
    display_name VARCHAR(50) NOT NULL,
    permissions JSONB NOT NULL DEFAULT '{}',
    description TEXT,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 3. USERS
-- ============================================================
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email           VARCHAR(255) UNIQUE,
    phone           VARCHAR(20) UNIQUE,
    hashed_password VARCHAR(255) NOT NULL,
    full_name       VARCHAR(200) NOT NULL,
    role_id         UUID REFERENCES roles(id) ON DELETE SET NULL,
    language_code   VARCHAR(10) DEFAULT 'en',
    avatar_url      TEXT,
    is_active       BOOLEAN DEFAULT TRUE,
    is_verified     BOOLEAN DEFAULT FALSE,
    last_login_at   TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_role ON users(role_id);

-- ============================================================
-- 4. ZONES (from Zone_Boundaries.csv — 32 zones)
-- ============================================================
CREATE TABLE zones (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    zone_name           VARCHAR(100) NOT NULL,
    centroid            GEOMETRY(POINT, 4326),
    centroid_lat        DOUBLE PRECISION NOT NULL,
    centroid_lng        DOUBLE PRECISION NOT NULL,
    boundary            GEOMETRY(POLYGON, 4326),
    approx_boundary_pts INTEGER,
    crowd_density       VARCHAR(20) DEFAULT 'medium',  -- low, medium, high, critical
    risk_level          VARCHAR(20) DEFAULT 'normal',   -- normal, elevated, high, critical
    is_active           BOOLEAN DEFAULT TRUE,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_zones_centroid ON zones USING GIST(centroid);
CREATE INDEX idx_zones_boundary ON zones USING GIST(boundary);

-- ============================================================
-- 5. POLICE STATIONS (from Police_Stations.csv — 14 stations)
-- ============================================================
CREATE TABLE police_stations (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    station_name    VARCHAR(200) NOT NULL,
    location        GEOMETRY(POINT, 4326),
    longitude       DOUBLE PRECISION NOT NULL,
    latitude        DOUBLE PRECISION NOT NULL,
    jurisdiction    GEOMETRY(POLYGON, 4326),
    phone           VARCHAR(20),
    officer_count   INTEGER DEFAULT 0,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_police_stations_location ON police_stations USING GIST(location);

-- ============================================================
-- 6. CCTV LOCATIONS (from CCTV_Locations.csv — 1,280 cameras)
-- ============================================================
CREATE TABLE cctv_locations (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    camera_id   VARCHAR(20) UNIQUE NOT NULL,
    location    GEOMETRY(POINT, 4326),
    longitude   DOUBLE PRECISION NOT NULL,
    latitude    DOUBLE PRECISION NOT NULL,
    zone_id     UUID REFERENCES zones(id) ON DELETE SET NULL,
    status      VARCHAR(20) DEFAULT 'active',  -- active, inactive, maintenance
    coverage_angle FLOAT,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_cctv_location ON cctv_locations USING GIST(location);
CREATE INDEX idx_cctv_zone ON cctv_locations(zone_id);

-- ============================================================
-- 7. CHOKEPOINTS & PARKING (from Chokepoints_Parking.csv — 85)
-- ============================================================
CREATE TABLE chokepoints (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    location_name   VARCHAR(200) NOT NULL,
    category        VARCHAR(50) NOT NULL,  -- Traffic choke point, Parking, Transfer node, etc.
    location        GEOMETRY(POINT, 4326),
    longitude       DOUBLE PRECISION NOT NULL,
    latitude        DOUBLE PRECISION NOT NULL,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_chokepoints_location ON chokepoints USING GIST(location);
CREATE INDEX idx_chokepoints_category ON chokepoints(category);

-- ============================================================
-- 8. MEDICAL CONDITIONS (extracted from CSV descriptions)
-- ============================================================
CREATE TABLE medical_conditions (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        VARCHAR(100) NOT NULL,
    severity    VARCHAR(20) NOT NULL,  -- mild, moderate, severe, critical
    description TEXT,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 9. MISSING PERSONS (from Synthetic_Missing_Persons_2500.csv)
-- ============================================================
CREATE TABLE missing_persons (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    case_id             VARCHAR(20) UNIQUE NOT NULL,  -- KMP-2027-XXXXX
    reporter_id         UUID REFERENCES users(id) ON DELETE SET NULL,
    
    -- Person Details
    missing_person_name VARCHAR(200),
    gender              VARCHAR(20),        -- Male, Female, Unknown
    age_band            VARCHAR(10),         -- 0-12, 13-17, 18-40, 41-60, 61-70, 71-80, 80+
    state               VARCHAR(100),
    district            VARCHAR(100),
    language            VARCHAR(50),
    
    -- Description
    physical_description TEXT,
    clothing_description TEXT,
    photo_url           TEXT,
    unique_identifiers  TEXT,
    
    -- Location
    last_seen_location  VARCHAR(200),
    last_seen_lat       DOUBLE PRECISION,
    last_seen_lng       DOUBLE PRECISION,
    last_seen_point     GEOMETRY(POINT, 4326),
    last_seen_zone_id   UUID REFERENCES zones(id),
    
    -- Status & Priority
    status              VARCHAR(30) NOT NULL DEFAULT 'Pending',  -- Pending, Searching, Reunited, Transferred to hospital, Unresolved
    priority            VARCHAR(20) DEFAULT 'Medium',            -- Low, Medium, High, Critical
    priority_score      FLOAT,
    
    -- Reporting
    reported_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reporting_center    VARCHAR(200),
    reporter_mobile     VARCHAR(20),
    
    -- Resolution
    resolution_hours    FLOAT,
    resolved_at         TIMESTAMPTZ,
    
    -- Flags
    is_duplicate_report BOOLEAN DEFAULT FALSE,
    is_child            BOOLEAN GENERATED ALWAYS AS (age_band IN ('0-12', '13-17')) STORED,
    is_senior           BOOLEAN GENERATED ALWAYS AS (age_band IN ('71-80', '80+')) STORED,
    
    -- AI Extracted Data
    ai_extracted_data   JSONB DEFAULT '{}',
    
    -- Metadata
    remarks             TEXT,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_mp_case_id ON missing_persons(case_id);
CREATE INDEX idx_mp_status ON missing_persons(status);
CREATE INDEX idx_mp_priority ON missing_persons(priority);
CREATE INDEX idx_mp_reported_at ON missing_persons(reported_at);
CREATE INDEX idx_mp_last_seen ON missing_persons USING GIST(last_seen_point);
CREATE INDEX idx_mp_zone ON missing_persons(last_seen_zone_id);
CREATE INDEX idx_mp_name_trgm ON missing_persons USING GIN(missing_person_name gin_trgm_ops);
CREATE INDEX idx_mp_description_trgm ON missing_persons USING GIN(physical_description gin_trgm_ops);

-- ============================================================
-- 10. REPORTS (one-to-one with missing_persons initially)
-- ============================================================
CREATE TABLE reports (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    missing_person_id   UUID REFERENCES missing_persons(id) ON DELETE CASCADE,
    reporter_id         UUID REFERENCES users(id) ON DELETE SET NULL,
    source              VARCHAR(30) NOT NULL DEFAULT 'text',  -- voice, text, photo, officer, aadhaar
    raw_input           TEXT,
    ai_processed_data   JSONB DEFAULT '{}',
    language            VARCHAR(50),
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_reports_mp ON reports(missing_person_id);

-- ============================================================
-- 11. VOLUNTEERS
-- ============================================================
CREATE TABLE volunteers (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    current_location GEOMETRY(POINT, 4326),
    current_lat     DOUBLE PRECISION,
    current_lng     DOUBLE PRECISION,
    is_available    BOOLEAN DEFAULT TRUE,
    languages       TEXT[] DEFAULT '{}',
    skills          TEXT[] DEFAULT '{}',
    current_workload INTEGER DEFAULT 0,
    max_workload    INTEGER DEFAULT 5,
    assigned_zone_id UUID REFERENCES zones(id),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_volunteers_location ON volunteers USING GIST(current_location);
CREATE INDEX idx_volunteers_available ON volunteers(is_available);

-- ============================================================
-- 12. ASSIGNMENTS (case → volunteer)
-- ============================================================
CREATE TABLE assignments (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    case_id         UUID REFERENCES missing_persons(id) ON DELETE CASCADE,
    volunteer_id    UUID REFERENCES volunteers(id) ON DELETE SET NULL,
    status          VARCHAR(30) NOT NULL DEFAULT 'assigned',  -- assigned, accepted, in_progress, completed, cancelled
    priority        VARCHAR(20),
    notes           TEXT,
    assigned_at     TIMESTAMPTZ DEFAULT NOW(),
    accepted_at     TIMESTAMPTZ,
    completed_at    TIMESTAMPTZ,
    created_by      UUID REFERENCES users(id)
);

CREATE INDEX idx_assignments_case ON assignments(case_id);
CREATE INDEX idx_assignments_volunteer ON assignments(volunteer_id);
CREATE INDEX idx_assignments_status ON assignments(status);

-- ============================================================
-- 13. NOTIFICATIONS
-- ============================================================
CREATE TABLE notifications (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
    case_id     UUID REFERENCES missing_persons(id) ON DELETE SET NULL,
    type        VARCHAR(50) NOT NULL,  -- case_registered, status_update, volunteer_assigned, match_found, face_match, aadhaar_match
    title       VARCHAR(200),
    message     TEXT NOT NULL,
    language    VARCHAR(50) DEFAULT 'en',
    is_read     BOOLEAN DEFAULT FALSE,
    priority    VARCHAR(20) DEFAULT 'normal',  -- low, normal, high, critical
    metadata    JSONB DEFAULT '{}',
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_read ON notifications(is_read);
CREATE INDEX idx_notifications_created ON notifications(created_at DESC);

-- ============================================================
-- 14. TIMELINE EVENTS (incident audit trail)
-- ============================================================
CREATE TABLE timeline_events (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    case_id     UUID REFERENCES missing_persons(id) ON DELETE CASCADE,
    event_type  VARCHAR(50) NOT NULL,  -- registered, updated, assigned, searching, found, reunited, escalated, face_match, aadhaar_match
    title       VARCHAR(200),
    description TEXT,
    actor_id    UUID REFERENCES users(id),
    actor_name  VARCHAR(200),
    metadata    JSONB DEFAULT '{}',
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_timeline_case ON timeline_events(case_id);
CREATE INDEX idx_timeline_created ON timeline_events(created_at);

-- ============================================================
-- 15. PREDICTIONS (AI model outputs)
-- ============================================================
CREATE TABLE predictions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    case_id         UUID REFERENCES missing_persons(id) ON DELETE CASCADE,
    prediction_type VARCHAR(50) NOT NULL,  -- priority, search_zone, duplicate, face_match
    data            JSONB NOT NULL,         -- Model output
    confidence      FLOAT,
    model_version   VARCHAR(50),
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_predictions_case ON predictions(case_id);
CREATE INDEX idx_predictions_type ON predictions(prediction_type);

-- ============================================================
-- 16. DUPLICATE CASES
-- ============================================================
CREATE TABLE duplicate_cases (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    case_a_id       UUID REFERENCES missing_persons(id) ON DELETE CASCADE,
    case_b_id       UUID REFERENCES missing_persons(id) ON DELETE CASCADE,
    similarity_score FLOAT NOT NULL,
    match_type      VARCHAR(30) DEFAULT 'text',  -- text, face, aadhaar
    status          VARCHAR(20) DEFAULT 'pending',  -- pending, merged, dismissed
    reviewed_by     UUID REFERENCES users(id),
    reviewed_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(case_a_id, case_b_id)
);

CREATE INDEX idx_duplicates_status ON duplicate_cases(status);

-- ============================================================
-- 17. AUDIT LOGS
-- ============================================================
CREATE TABLE audit_logs (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID REFERENCES users(id) ON DELETE SET NULL,
    action          VARCHAR(100) NOT NULL,
    resource_type   VARCHAR(50),
    resource_id     UUID,
    old_data        JSONB,
    new_data        JSONB,
    ip_address      VARCHAR(45),
    user_agent      TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_audit_user ON audit_logs(user_id);
CREATE INDEX idx_audit_created ON audit_logs(created_at DESC);
CREATE INDEX idx_audit_resource ON audit_logs(resource_type, resource_id);

-- ============================================================
-- 18. FACE EMBEDDINGS (pgvector — for face recognition)
-- ============================================================
CREATE TABLE face_embeddings (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    missing_person_id   UUID REFERENCES missing_persons(id) ON DELETE CASCADE,
    embedding           VECTOR(128) NOT NULL,
    photo_url           TEXT NOT NULL,
    source              VARCHAR(30) NOT NULL DEFAULT 'reporter',  -- reporter, volunteer, police, cctv
    quality_score       FLOAT,
    num_faces_detected  INTEGER DEFAULT 1,
    is_active           BOOLEAN DEFAULT TRUE,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    created_by          UUID REFERENCES users(id)
);

CREATE INDEX idx_face_embedding_ivfflat 
    ON face_embeddings USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100);
CREATE INDEX idx_face_mp ON face_embeddings(missing_person_id);

-- ============================================================
-- 19. AADHAAR RECORDS (privacy-first — hashed only)
-- ============================================================
CREATE TABLE aadhaar_records (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    missing_person_id   UUID REFERENCES missing_persons(id) ON DELETE SET NULL,
    aadhaar_hash        VARCHAR(64) NOT NULL,        -- SHA-256 of Aadhaar number
    name_extracted      VARCHAR(200),
    dob_extracted       DATE,
    gender_extracted    VARCHAR(20),
    address_extracted   TEXT,
    state_extracted     VARCHAR(100),
    district_extracted  VARCHAR(100),
    raw_ocr_confidence  FLOAT,
    match_status        VARCHAR(20) DEFAULT 'pending',  -- pending, matched, no_match
    matched_person_id   UUID REFERENCES missing_persons(id),
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    created_by          UUID REFERENCES users(id)
);

CREATE INDEX idx_aadhaar_hash ON aadhaar_records(aadhaar_hash);
CREATE INDEX idx_aadhaar_match ON aadhaar_records(match_status);

-- ============================================================
-- TRIGGER: Auto-update updated_at
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_missing_persons_updated_at BEFORE UPDATE ON missing_persons
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_zones_updated_at BEFORE UPDATE ON zones
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_volunteers_updated_at BEFORE UPDATE ON volunteers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- SEED: Static Roles
-- ============================================================
INSERT INTO roles (name, display_name, permissions, description) VALUES
('family', 'Family / Reporter', '{"cases": ["create", "read_own"], "notifications": ["read"], "reports": ["create"]}', 'Family members who report missing persons'),
('police', 'Police Officer', '{"cases": ["create", "read", "update", "delete"], "volunteers": ["read", "assign"], "duplicates": ["review"], "reports": ["generate"], "face": ["match"], "aadhaar": ["extract", "match"]}', 'Police officers managing cases'),
('volunteer', 'Volunteer', '{"cases": ["read_assigned"], "assignments": ["accept", "update"], "observations": ["create"], "face": ["scan"]}', 'Field volunteers assisting in search'),
('admin', 'Command Center Admin', '{"*": ["*"]}', 'Full system access');

-- ============================================================
-- SEED: Languages (from CSV — 10 unique)
-- ============================================================
INSERT INTO languages (code, name, native_name) VALUES
('hi', 'Hindi', 'हिन्दी'),
('bn', 'Bengali', 'বাংলা'),
('kn', 'Kannada', 'ಕನ್ನಡ'),
('mai', 'Maithili', 'मैथिली'),
('gu', 'Gujarati', 'ગુજરાતી'),
('te', 'Telugu', 'తెలుగు'),
('bho', 'Bhojpuri', 'भोजपुरी'),
('awa', 'Awadhi', 'अवधी'),
('ta', 'Tamil', 'தமிழ்'),
('mr', 'Marathi', 'मराठी'),
('en', 'English', 'English');
