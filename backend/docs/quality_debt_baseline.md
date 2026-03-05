# Backend Quality Debt Baseline

This document records current lint/type debt so backend CI can remain usable as a required check
while still blocking regressions on newly changed backend Python files.

## Baseline Snapshot

- Measured at: 2026-03-04 (Asia/Seoul)
- Commands:
  - `cd backend && uv run ruff check app tests --statistics`
  - `cd backend && UV_CACHE_DIR=.uv-cache uv run mypy app`
- Results:
  - Ruff: 453 issues
  - Mypy: 68 issues

## CI Policy

- Full functional gates are always global:
  - `python3 -m compileall app tests alembic`
  - `uv run pytest -q`
  - `uv run python -c "from app.main import app; assert app.title"`
  - `uv run alembic upgrade head`
- Lint/type strict gate is changed-files based:
  - `ruff` runs only on changed backend Python files.
  - `mypy` runs only on derived `app.*` module targets from changed backend Python files.
- If no backend Python files changed, strict lint/type gate is skipped.

## Regression Rule

- New/modified backend Python code must not introduce new lint/type debt.
- Existing baseline debt is tracked separately and cleaned incrementally by dedicated tickets.

## Required Check Name

- `Backend CI / backend-gates`
- Configure this exact name in GitHub branch protection required checks.
- Docs-only backend changes still execute the workflow and end with success.
- Heavy backend gates run only for runtime-affecting changes.

## Local Commands

- `cd backend && bash scripts/backend_ci.sh sync`
- `cd backend && bash scripts/backend_ci.sh quality-strict`
- `cd backend && bash scripts/backend_ci.sh test`
- `cd backend && bash scripts/backend_ci.sh alembic`
- `cd backend && bash scripts/backend_ci.sh full`
