# Backend Production Readiness (Post B1.7)

Last updated: 2026-03-02 (KST)

## 0) Execution Assets

Use the following operational assets to execute OPS-1:

- Runbook: `docs/ops/ops_1_production_readiness.md`
- Secret rotation checklist: `docs/ops/secret_rotation_checklist.md`
- Monitoring baseline: `docs/ops/monitoring_alert_baseline.md`
- Script guide: `backend/scripts/ops/README.md`
- Environment check: `backend/scripts/ops/check_environment.sh`
- R2 lifecycle backup/apply:
  - `backend/scripts/ops/r2_lifecycle_backup.sh`
  - `backend/scripts/ops/r2_lifecycle_apply.sh`
- Backup/restore drill: `backend/scripts/ops/backup_restore_drill.sh`
- Monitoring SQL pack: `backend/scripts/ops/monitoring_queries.sql`

## 1) B1 Completion Gate

- B1.0: Approved
- B1.1: Approved
- B1.2: Approved
- B1.3: Approved
- B1.4: Approved
- B1.5: Approved
- B1.6: Approved
- B1.7: Approved

Backend phase B1 is complete in code and test coverage.

## 2) Fixed Policy Values (Must Not Drift)

- Access token TTL: 15 minutes
- Refresh token TTL: 30 days
- Refresh token storage: opaque token, hash-only in DB, rotation and reuse detection required
- Invite code TTL: 10 minutes, one-time consume only
- Link cardinality: parent up to 5 children, child up to 2 parents
- DB timestamp storage timezone: UTC
- `dayKey` / `weekKey` / `periodKey` calculation timezone: Asia/Seoul
- User-facing report time display: KST
- R2 bucket policy: private only
- Signed URL TTL: upload 5 minutes, download default 5 minutes

Source: backend policy constants and validation logic in `backend/app/core/policies.py`.

## 3) P0 (Release-Blocking) Checklist

### 3.1 Migration Freeze Policy

Status: Done (policy documented and enforced in workflow)

- Do not modify already-shared Alembic revisions.
- Add corrective changes only through new revision files (`0008+` and onward).
- Validate every new revision with:
  - `cd backend && uv run alembic upgrade head`
  - clean DB bootstrap path

### 3.2 Required Runtime Environment Variables

Status: Done (declared in `.env.example` and validated by settings)

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

Additional provider/billing variables:

- `AI_OPENAI_BASE_URL`
- `AI_ANTHROPIC_BASE_URL`
- `AI_ARTIFACT_RETENTION_DAYS`
- `STRIPE_WEBHOOK_SECRET`
- `APP_STORE_SHARED_SECRET`
- `APP_STORE_VERIFY_URL`
- `APP_STORE_SANDBOX_VERIFY_URL`

### 3.3 DB Targeting and Alembic Procedure

Status: Done (documented procedure)

- Never run migrations against an ambiguous local DB target.
- Standard local sequence:
  1. `cd backend && docker compose up -d postgres redis`
  2. `cd backend && docker compose ps`
  3. Run Alembic with explicit runtime env:
     - `cd backend && UV_CACHE_DIR=.uv-cache DATABASE_URL=... REDIS_URL=... JWT_SECRET=... R2_ENDPOINT=... R2_BUCKET=... R2_ACCESS_KEY_ID=... R2_SECRET_ACCESS_KEY=... CONTENT_PIPELINE_API_KEY=... uv run alembic upgrade head`
- Keep `localhost:5432` ownership explicit (compose container vs local daemon).

### 3.4 Secret Handling and Rotation

Status: Done (runbook defined)

- `.env` must never be committed.
- Separate secrets by environment: dev / staging / production.
- Rotation minimum:
  - `JWT_SECRET`: rotate on credential incident and regular cadence.
  - `R2_ACCESS_KEY_ID` / `R2_SECRET_ACCESS_KEY`: rotate through dual-key overlap.
  - `CONTENT_PIPELINE_API_KEY`: rotate with zero-downtime switch window.
  - `AI_GENERATION_API_KEY`, `STRIPE_WEBHOOK_SECRET`, `APP_STORE_SHARED_SECRET`: rotate with rollout coordination.
- Rotation procedure:
  1. Provision new secret.
  2. Deploy with new + old accepted (if applicable).
  3. Cut traffic to new secret.
  4. Revoke old secret.
  5. Audit log + incident note.

### 3.5 Backup and Restore Baseline

Status: Done (minimum runbook defined)

PostgreSQL:

- Backup:
  - `pg_dump postgresql://<user>:<pass>@<host>:5432/<db> -Fc -f resol_backend_YYYYMMDD.dump`
- Restore:
  - `pg_restore -d postgresql://<user>:<pass>@<host>:5432/<db> --clean --if-exists resol_backend_YYYYMMDD.dump`

R2 objects:

- Preserve bucket versioning/lifecycle policy before release.
- Validate restore scope by object prefixes:
  - `content-assets/`
  - `ai-artifacts/`

Recovery drill (minimum):

- Quarterly restore drill into isolated staging DB + bucket.
- Verify API boot + migration state + signed URL issuance.

### 3.6 Logging and Redaction Policy

Status: Done (policy documented and code-aligned)

Must never log:

- Signed URL full strings
- API keys
- JWT access tokens
- Refresh token plaintext
- Full raw AI prompt/response text
- Full external billing references beyond minimal troubleshooting scope

Allowed:

- IDs, counts, status transitions, bounded error codes/messages
- Artifact object keys (no signed query params)

## 4) P1 (Pre-Beta Recommended) Status

### 4.1 Post-commit Enqueue Race

Status: Done in current backend.

- Commit-after enqueue behavior implemented for aggregation and AI jobs.

### 4.2 SQLite FK Teardown Warning

Status: Closed for current test baseline.

- Current pytest run shows no teardown warning.
- Follow-up doc retained for future schema changes.

### 4.3 Subscription Overlap DB Hardening

Status: Done.

- DB-level exclusion constraint added:
  - `ex_user_subscriptions_owner_entitlement_window`

### 4.4 AI Artifact Retention and Access Audit

Status: Done (baseline).

- Retention window configurable (`AI_ARTIFACT_RETENTION_DAYS`).
- Purge endpoint available:
  - `POST /internal/ai/jobs/artifacts/purge`
- Access audit captured when artifact signed download URL is issued.

### 4.5 R2 Lifecycle Policy

Status: Partially done in code, operator policy required.

- Code side: private-only access + signed URL TTL enforcement.
- Operator side (still required): cloud-side lifecycle and retention enforcement policy.

## 5) P2 (Post-Beta / Expansion) Status

### 5.1 External AI Provider Adapter

Status: Done (OpenAI/Anthropic adapter baseline implemented).

### 5.2 Billing Webhook and Receipt Verification

Status: Done (Stripe webhook + App Store verify baseline implemented).

### 5.3 Retry Backoff / Dead-letter

Status: Done for AI generation jobs.

### 5.4 Metrics / Alerting / Dashboards

Status: Pending operator implementation.

- Code includes operational signals (job status, dead-letter state, audit logs).
- Infra-side dashboards/alerts must be configured in the deployment platform.

### 5.5 Machine-readable Error Normalization

Status: Done (baseline).

- Error responses include:
  - `detail` (existing contract kept)
  - `errorCode` (machine-readable top-level code)

## 6) QA Scenario Coverage Map

Covered by automated tests:

- Parent without `CHILD_REPORTS` cannot read child reports.
- Student without weekly/monthly entitlement gets 403 on current exam APIs.
- Session start is gated by exam type entitlement.
- Existing owned session detail remains readable after subscription expiry.
- Parent-child unlink immediately removes student entitlement source.
- Duplicate sync event is deduplicated by `(student_id, idempotency_key)`.
- Latest logical attempt semantics are applied in report aggregation.
- AI-generated draft remains hidden from student current exam until published.
- Published generated revision is delivered through normal session flow.
- Internal APIs remain gated by internal API key and unaffected by subscription checks.
