#!/usr/bin/env bash
# ============================================================
# KumbhSathi AI — Backend container entrypoint
# Waits for Postgres, seeds the CSV data (idempotent), then runs the API.
# ============================================================
set -euo pipefail

echo "⏳ Waiting for database to be ready..."
python - <<'PY'
import asyncio, os, sys
import asyncpg

# Derive a plain (non-async-driver) DSN for a quick connectivity probe.
url = os.environ.get("DATABASE_URL", "")
dsn = url.replace("postgresql+asyncpg://", "postgresql://")

async def wait():
    for attempt in range(1, 61):
        try:
            conn = await asyncpg.connect(dsn)
            await conn.close()
            print(f"✓ Database reachable (attempt {attempt})")
            return
        except Exception as exc:  # noqa: BLE001
            print(f"  ...waiting ({attempt}/60): {exc}")
            await asyncio.sleep(2)
    print("❌ Database not reachable after 120s", file=sys.stderr)
    sys.exit(1)

asyncio.run(wait())
PY

echo "🌱 Seeding database from CSV (idempotent)..."
python -m scripts.import_csv || echo "⚠  Seeding skipped/failed (continuing) — check logs above."

echo "🚀 Starting API: $*"
exec "$@"
