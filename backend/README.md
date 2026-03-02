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

## Reproducible Verification Order

```bash
cd backend
uv sync --extra dev
docker compose config
docker compose up -d postgres redis
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
