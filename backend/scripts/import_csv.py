"""
KumbhSathi AI — CSV → PostgreSQL Seeder
=======================================

Imports the five workspace CSV files (the *sole* data source for this project)
into the PostgreSQL + PostGIS + pgvector database:

    1. Zone_Boundaries.csv          -> zones            (32)
    2. Police_Stations.csv          -> police_stations  (14)
    3. CCTV_Locations.csv           -> cctv_locations   (1,280, auto-assigned to nearest zone)
    4. Chokepoints_Parking.csv      -> chokepoints      (85)
    5. Synthetic_Missing_Persons_2500.csv -> missing_persons (2,500)

Also ensures the static `roles` and `languages` rows exist (idempotent), so the
seeder works even when the DB was created without running schema.sql's seed block.

Usage
-----
    # Assumes the schema (database/schema.sql) has already been applied.
    # Inside docker-compose, schema.sql runs automatically on first DB boot.
    python -m scripts.import_csv               # seed only empty tables (safe to re-run)
    python -m scripts.import_csv --reset       # TRUNCATE data tables, then re-seed
    python -m scripts.import_csv --data-dir ../data

The DATABASE_URL is read from app.core.config.settings (env-overridable).
"""
from __future__ import annotations

import argparse
import asyncio
import csv
import math
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

# Allow running both as `python -m scripts.import_csv` and `python scripts/import_csv.py`
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from geoalchemy2.elements import WKTElement  # noqa: E402
from sqlalchemy import func, select, text  # noqa: E402
from sqlalchemy.ext.asyncio import AsyncSession  # noqa: E402

from app.core.config import settings  # noqa: E402
from app.core.database import async_session_factory, engine  # noqa: E402
from app.models.models import (  # noqa: E402
    CCTVLocation,
    Chokepoint,
    Language,
    MissingPerson,
    PoliceStation,
    Role,
    Zone,
)


# ============================================================
# Helpers
# ============================================================
def _point(lng: float, lat: float) -> WKTElement:
    """Build a SRID-4326 POINT geometry from longitude/latitude."""
    return WKTElement(f"POINT({lng} {lat})", srid=4326)


def _f(value: str) -> Optional[float]:
    """Parse a float, tolerating empty strings."""
    value = (value or "").strip()
    if value == "" or value.lower() in ("nan", "none", "null"):
        return None
    try:
        return float(value)
    except ValueError:
        return None


def _bool(value: str) -> bool:
    return (value or "").strip().lower() in ("true", "1", "yes", "y")


def _parse_dt(value: str) -> datetime:
    """Parse 'YYYY-MM-DD HH:MM' (CSV format); fall back to now() on failure."""
    value = (value or "").strip()
    for fmt in ("%Y-%m-%d %H:%M", "%Y-%m-%d %H:%M:%S", "%Y-%m-%d"):
        try:
            return datetime.strptime(value, fmt).replace(tzinfo=timezone.utc)
        except ValueError:
            continue
    return datetime.now(timezone.utc)


# Age bands considered vulnerable -> seed a higher default priority.
_CHILD_BANDS = {"0-12", "13-17", "0-5", "6-12"}
_SENIOR_BANDS = {"61-70", "71-80", "80+", "81+", "60+"}


def _derive_priority(age_band: str, status: str) -> tuple[str, float]:
    """Heuristic seed priority. The ML PriorityPredictor (Phase 5) overrides this later."""
    band = (age_band or "").strip()
    status = (status or "").strip()
    score = 0.45
    if band in _CHILD_BANDS:
        score += 0.35
    elif band in _SENIOR_BANDS:
        score += 0.20
    if status in ("Pending", "Searching"):
        score += 0.10
    if status == "Unresolved":
        score += 0.20
    score = min(round(score, 2), 0.99)
    if score >= 0.80:
        label = "Critical"
    elif score >= 0.65:
        label = "High"
    elif score >= 0.45:
        label = "Medium"
    else:
        label = "Low"
    return label, score


def _read_csv(path: Path) -> list[dict]:
    with path.open("r", encoding="utf-8-sig", newline="") as fh:
        return list(csv.DictReader(fh))


def _nearest_zone_id(lng: float, lat: float, zones: list[tuple]) -> Optional[str]:
    """Nearest zone by centroid (planar distance — fine at city scale)."""
    best_id, best_d = None, math.inf
    for zid, zlat, zlng in zones:
        d = (zlat - lat) ** 2 + (zlng - lng) ** 2
        if d < best_d:
            best_d, best_id = d, zid
    return best_id


# ============================================================
# Static reference data (idempotent)
# ============================================================
_ROLES = [
    ("family", "Family / Reporter",
     {"cases": ["create", "read_own"], "notifications": ["read"], "reports": ["create"]},
     "Family members who report missing persons"),
    ("police", "Police Officer",
     {"cases": ["create", "read", "update", "delete"], "volunteers": ["read", "assign"],
      "duplicates": ["review"], "reports": ["generate"], "face": ["match"],
      "aadhaar": ["extract", "match"]},
     "Police officers managing cases"),
    ("volunteer", "Volunteer",
     {"cases": ["read_assigned"], "assignments": ["accept", "update"],
      "observations": ["create"], "face": ["scan"]},
     "Field volunteers assisting in search"),
    ("admin", "Command Center Admin", {"*": ["*"]}, "Full system access"),
]

_LANGUAGES = [
    ("hi", "Hindi", "हिन्दी"), ("bn", "Bengali", "বাংলা"), ("kn", "Kannada", "ಕನ್ನಡ"),
    ("mai", "Maithili", "मैथिली"), ("gu", "Gujarati", "ગુજરાતી"), ("te", "Telugu", "తెలుగు"),
    ("bho", "Bhojpuri", "भोजपुरी"), ("awa", "Awadhi", "अवधी"), ("ta", "Tamil", "தமிழ்"),
    ("mr", "Marathi", "मराठी"), ("en", "English", "English"),
]


async def seed_reference(session: AsyncSession) -> None:
    existing_roles = {r for (r,) in (await session.execute(select(Role.name))).all()}
    for name, display, perms, desc in _ROLES:
        if name not in existing_roles:
            session.add(Role(name=name, display_name=display, permissions=perms, description=desc))

    existing_langs = {c for (c,) in (await session.execute(select(Language.code))).all()}
    for code, name, native in _LANGUAGES:
        if code not in existing_langs:
            session.add(Language(code=code, name=name, native_name=native))
    await session.flush()
    print("  ✓ roles & languages ensured")


# ============================================================
# Importers
# ============================================================
async def _count(session: AsyncSession, model) -> int:
    return (await session.execute(select(func.count()).select_from(model))).scalar_one()


async def import_zones(session: AsyncSession, data_dir: Path) -> list[tuple]:
    rows = _read_csv(data_dir / "Zone_Boundaries.csv")
    for r in rows:
        lat, lng = _f(r["centroid_lat"]), _f(r["centroid_lng"])
        session.add(Zone(
            zone_name=r["zone_name"].strip(),
            centroid_lat=lat,
            centroid_lng=lng,
            centroid=_point(lng, lat) if lat is not None and lng is not None else None,
            approx_boundary_pts=int(_f(r.get("approx_boundary_points")) or 0),
        ))
    await session.flush()
    zones = [(str(z.id), z.centroid_lat, z.centroid_lng)
             for z in (await session.execute(select(Zone))).scalars().all()]
    print(f"  ✓ zones: {len(rows)}")
    return zones


async def import_police_stations(session: AsyncSession, data_dir: Path) -> None:
    rows = _read_csv(data_dir / "Police_Stations.csv")
    for r in rows:
        lng, lat = _f(r["longitude"]), _f(r["latitude"])
        session.add(PoliceStation(
            station_name=r["station_name"].strip(),
            longitude=lng, latitude=lat,
            location=_point(lng, lat) if lat is not None and lng is not None else None,
        ))
    await session.flush()
    print(f"  ✓ police_stations: {len(rows)}")


async def import_cctv(session: AsyncSession, data_dir: Path, zones: list[tuple]) -> None:
    rows = _read_csv(data_dir / "CCTV_Locations.csv")
    for r in rows:
        lng, lat = _f(r["longitude"]), _f(r["latitude"])
        session.add(CCTVLocation(
            camera_id=r["camera_id"].strip(),
            longitude=lng, latitude=lat,
            location=_point(lng, lat) if lat is not None and lng is not None else None,
            zone_id=_nearest_zone_id(lng, lat, zones) if (lat is not None and zones) else None,
        ))
    await session.flush()
    print(f"  ✓ cctv_locations: {len(rows)} (auto-assigned to nearest zone)")


async def import_chokepoints(session: AsyncSession, data_dir: Path) -> None:
    rows = _read_csv(data_dir / "Chokepoints_Parking.csv")
    for r in rows:
        lng, lat = _f(r["longitude"]), _f(r["latitude"])
        session.add(Chokepoint(
            location_name=r["location_name"].strip(),
            category=r["category"].strip(),
            longitude=lng, latitude=lat,
            location=_point(lng, lat) if lat is not None and lng is not None else None,
        ))
    await session.flush()
    print(f"  ✓ chokepoints: {len(rows)}")


async def import_missing_persons(session: AsyncSession, data_dir: Path) -> None:
    rows = _read_csv(data_dir / "Synthetic_Missing_Persons_2500.csv")
    for r in rows:
        priority, score = _derive_priority(r.get("age_band", ""), r.get("status", ""))
        session.add(MissingPerson(
            case_id=r["case_id"].strip(),
            reported_at=_parse_dt(r.get("reported_at", "")),
            missing_person_name=(r.get("missing_person_name") or "").strip() or None,
            gender=(r.get("gender") or "").strip() or None,
            age_band=(r.get("age_band") or "").strip() or None,
            state=(r.get("state") or "").strip() or None,
            district=(r.get("district") or "").strip() or None,
            language=(r.get("language") or "").strip() or None,
            last_seen_location=(r.get("last_seen_location") or "").strip() or None,
            reporting_center=(r.get("reporting_center") or "").strip() or None,
            reporter_mobile=(r.get("reporter_mobile") or "").strip() or None,
            physical_description=(r.get("physical_description") or "").strip() or None,
            status=(r.get("status") or "Pending").strip(),
            resolution_hours=_f(r.get("resolution_hours")),
            is_duplicate_report=_bool(r.get("is_duplicate_report")),
            remarks=(r.get("remarks") or "").strip() or None,
            priority=priority,
            priority_score=score,
        ))
    await session.flush()
    print(f"  ✓ missing_persons: {len(rows)}")


# Order matters: zones before cctv (FK + nearest-zone assignment).
_DATA_TABLES = ["missing_persons", "cctv_locations", "chokepoints",
                "police_stations", "zones"]


async def reset_data_tables(session: AsyncSession) -> None:
    print("⚠  --reset: truncating data tables (roles/languages/users preserved)")
    await session.execute(text(
        "TRUNCATE TABLE " + ", ".join(_DATA_TABLES) + " RESTART IDENTITY CASCADE"
    ))
    await session.flush()


# ============================================================
# Main
# ============================================================
async def run(data_dir: Path, reset: bool) -> None:
    print(f"📥 KumbhSathi CSV seeder  |  data dir: {data_dir}")
    if not data_dir.exists():
        raise SystemExit(f"❌ Data directory not found: {data_dir}")

    async with async_session_factory() as session:
        await seed_reference(session)

        if reset:
            await reset_data_tables(session)

        # Skip already-populated tables unless we just reset them.
        if await _count(session, Zone) == 0:
            zones = await import_zones(session, data_dir)
        else:
            zones = [(str(z.id), z.centroid_lat, z.centroid_lng)
                     for z in (await session.execute(select(Zone))).scalars().all()]
            print(f"  • zones already populated ({len(zones)}) — skipped")

        if await _count(session, PoliceStation) == 0:
            await import_police_stations(session, data_dir)
        else:
            print("  • police_stations already populated — skipped")

        if await _count(session, CCTVLocation) == 0:
            await import_cctv(session, data_dir, zones)
        else:
            print("  • cctv_locations already populated — skipped")

        if await _count(session, Chokepoint) == 0:
            await import_chokepoints(session, data_dir)
        else:
            print("  • chokepoints already populated — skipped")

        if await _count(session, MissingPerson) == 0:
            await import_missing_persons(session, data_dir)
        else:
            print("  • missing_persons already populated — skipped")

        await session.commit()

    await engine.dispose()
    print("✅ Seed complete.")


def _resolve_data_dir() -> Path:
    """Pick the first existing data directory across local + container layouts."""
    here = Path(__file__).resolve()
    candidates = [
        Path(os.environ["DATA_DIR"]) if os.environ.get("DATA_DIR") else None,
        here.parent.parent.parent / "data",   # local dev: <repo>/data
        here.parent.parent / "data",          # container: /app/data
        Path("/app/data"),
        Path("./data"),
    ]
    for c in candidates:
        if c and c.exists():
            return c
    return here.parent.parent.parent / "data"  # fallback (error surfaced in run())


def main() -> None:
    parser = argparse.ArgumentParser(description="Seed KumbhSathi DB from workspace CSVs.")
    parser.add_argument("--data-dir", default=str(_resolve_data_dir()),
                        help="Directory containing the CSV files (auto-detected by default)")
    parser.add_argument("--reset", action="store_true",
                        help="Truncate data tables before seeding")
    args = parser.parse_args()
    asyncio.run(run(Path(args.data_dir), args.reset))


if __name__ == "__main__":
    main()
