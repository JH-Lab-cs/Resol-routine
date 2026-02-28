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
  - parent -> many children
  - child -> up to two parents (configurable)

## B1.2 Sync

- Event-level ingestion endpoints
- Idempotent event write rules
- Replay-safe aggregation triggers
- Sync error contract for mobile retry

## B1.3 Reports

- Parent-facing report aggregation from events
- API for report summaries/details
- Versioned schema compatibility policy

## B1.4 Content Bank

- Question bank schema for LISTENING/READING
- Track/skill/type constraints
- Publish flags and versioning metadata

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
