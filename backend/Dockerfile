# ============================================================
# KumbhSathi AI — FastAPI Backend Image
# Python 3.11 + dlib (face_recognition) + EasyOCR/torch + PostGIS client
# ============================================================
FROM python:3.11-slim AS base

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# ---- System dependencies ----
# build-essential + cmake + BLAS/LAPACK + X11  -> required to build dlib
# libgl1 + libglib2.0-0                        -> required by opencv (EasyOCR)
# libpq-dev                                    -> Postgres client headers
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        libopenblas-dev \
        liblapack-dev \
        libx11-dev \
        libgl1 \
        libglib2.0-0 \
        libpq-dev \
        curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ---- Python dependencies (cached layer) ----
COPY requirements.txt .
RUN pip install --upgrade pip && pip install -r requirements.txt

# ---- Application code ----
COPY . .

RUN chmod +x /app/entrypoint.sh

EXPOSE 8000

# entrypoint: wait for DB -> seed CSVs (idempotent) -> launch uvicorn
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
