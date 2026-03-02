# Resol Routine Backend (B1.0)

This directory contains the phase-1 backend baseline for Resol Routine.

## Prerequisites

- Python 3.12
- [uv](https://docs.astral.sh/uv/)
- Docker (with `docker compose`)

## Stack

- Python 3.12
- FastAPI
- PostgreSQL
- Celery + Redis
- SQLAlchemy 2.x + Alembic
- Pydantic v2

## Environment Setup

```bash
cd backend
cp .env.example .env
```

Set required secrets and credentials in `.env` before starting.
Access/refresh TTL, JWT algorithm, signed URL TTL, and timezone policies are fixed in code.

Required runtime variables:

- `DATABASE_URL`
- `REDIS_URL`
- `JWT_SECRET`
- `R2_ENDPOINT`
- `R2_BUCKET`
- `R2_ACCESS_KEY_ID`
- `R2_SECRET_ACCESS_KEY`
- `CONTENT_PIPELINE_API_KEY`
- `AI_GENERATION_PROVIDER`
- `AI_GENERATION_API_KEY` (required for external providers)
- `AI_MOCK_EXAM_MODEL`
- `AI_MOCK_EXAM_PROMPT_TEMPLATE_VERSION`

## Reproducible Verification Order

```bash
cd backend
uv sync --extra dev
docker compose config
docker compose up -d postgres redis
UV_CACHE_DIR=.uv-cache \
DATABASE_URL='postgresql+psycopg://resol:resol@localhost:5432/resol_backend' \
REDIS_URL='redis://localhost:6379/0' \
JWT_SECRET='replace-with-real-secret' \
R2_ENDPOINT='https://example.r2.cloudflarestorage.com' \
R2_BUCKET='resol-private-bucket' \
R2_ACCESS_KEY_ID='replace-with-real-key-id' \
R2_SECRET_ACCESS_KEY='replace-with-real-key' \
CONTENT_PIPELINE_API_KEY='replace-with-real-internal-key' \
uv run alembic upgrade head
uv run pytest
```

## Migration Policy (Post B1.5)

- Treat existing Alembic revisions as immutable once published.
- Do not edit previously applied revisions in shared history.
- Add new corrective revisions only (next sequence from current head).
- Validate from an empty database when adding a new revision chain.

## Run API

```bash
cd backend
uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Health check:

```bash
curl http://127.0.0.1:8000/health
```

## Worker

```bash
cd backend
uv run celery -A app.workers.celery_app:celery_app worker --loglevel=info
```

## Production Runbook

See `docs/backend_production_readiness.md` for:

- migration freeze policy
- secret rotation runbook
- DB target and migration safety procedure
- backup/restore baseline
- logging redaction policy
- QA readiness matrix
