# Backend Scope (Phase-1)

This document narrows backend phase-1 work into implementation slices.

## B1.0 Architecture Baseline

- API gateway + auth middleware
- Event ingestion API
- Report aggregation worker
- Content bank storage
- Mock exam publish storage
- Audit logging for parent-child link actions

## B1.1 Auth / Parent-Child Link

- Role-aware authentication (student, parent)
- Parent-child link by one-time invite code
- Link/unlink APIs with audit log
- Link constraints:
  - parent -> up to 5 children
  - child -> up to 2 parents
- Access/refresh session policy:
  - access token JWT TTL: 15m
  - refresh token opaque TTL: 30d
  - refresh rotation + reuse detection required
  - refresh token table fields must include:
    - `id`, `user_id`, `device_id`, `token_hash`, `family_id`
    - `issued_at`, `expires_at`, `rotated_at`, `revoked_at`
    - `replaced_by_token_id`, `reuse_detected_at`, `ip`, `user_agent`
- Invite security policy:
  - one-time code, 10m TTL, hash-only storage
  - verify rate limit: 5 attempts / 10 minutes per parent+IP
  - verify rate limit: 5 attempts / 10 minutes per invite_code+IP
  - device-based throttling when `device_id` is available

## B1.2 Sync

- Event-level ingestion endpoints
- Idempotent event write rules
- Replay-safe aggregation triggers
- Sync error contract for mobile retry
- Event table policy:
  - append-only `study_events`
  - `UNIQUE(student_id, idempotency_key)`
  - required event fields: `event_type`, `schema_version`, `device_id`, `occurred_at_client`, `received_at_server`, `idempotency_key`
- Time policy:
  - UTC for DB storage
  - Asia/Seoul for `dayKey`/`weekKey`/`periodKey` boundaries
  - KST for user-facing report timestamp display

## B1.3 Reports

- Parent-facing report aggregation from events
- API for report summaries/details
- Versioned schema compatibility policy

## B1.4 Content Bank

- Question bank schema for LISTENING/READING
- Track/skill/type constraints
- Publish flags and versioning metadata
- Lifecycle contract:
  - enum stays minimal: `DRAFT`, `PUBLISHED`, `ARCHIVED`
  - validation/review are trace-field gates (`validator_version`, `validated_at`, `reviewer_identity`, `reviewed_at`)
  - `VALIDATED` / `IN_REVIEW` / `APPROVED` are not DB enum states
- Object storage policy:
  - Cloudflare R2 private buckets only
  - signed URL access only (or server proxy)
  - default signed URL TTL: upload 5m, download 5m (max 10m with explicit control)
  - MIME/type allowlist validation required

## B1.5 Mock Assembly

- Weekly/monthly assembly service
- Deterministic period-key based publish
- Rule enforcement:
  - weekly 10+10
  - monthly 17+28

## B1.6 AI Worker

- Draft generation pipeline
- Validation hooks
- Human review gate (no auto-publish in phase-1)

## Explicit Non-goals in Phase-1

- Real-time streaming sync
- Public teacher/admin console
- Final billing production rollout
- Full CMS authoring UI
