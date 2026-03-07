# Backend Handoff

This document is the backend handoff baseline for the next chat/session.

## A. Product Overview

- App: Resol Routine
- Target users: Korean learners (middle school grade 3 to high school grade 3)
- Roles:
  - Student
  - Parent
- Tracks:
  - M3
  - H1
  - H2
  - H3

## B. Learning Rules

- Daily routine:
  - LISTENING 3 + READING 3 (fixed total 6)
- Today vocab quiz:
  - 20 questions, 5 options
- Weekly mock exam:
  - LISTENING 10 + READING 10 (total 20)
- Monthly mock exam:
  - LISTENING 17 + READING 28 (total 45)

## C. Current Frontend Status

- Daily quiz flow: implemented
- Vocab + custom vocab CRUD: implemented
- Weekly/monthly mock flows (resume/completion/result/history): implemented
- Wrong notes integration (daily + mock): implemented
- Report schema v5 (export/import): implemented
- Parent home report section:
  - End-user path: placeholder only before backend link rollout
  - File-based report import/export: dev-only QA path remains available

## D. Backend Goals

- Parent-child linking via invite code
- Automatic report sync (student -> parent)
- Content backend service
- Mock exam assembly/orchestration service
- AI generation worker pipeline
- Subscription and entitlement backend

## E. Server Contracts (Must Keep)

- Enum values:
  - Track: `M3`, `H1`, `H2`, `H3`
  - Skill: `LISTENING`, `READING`
  - Mock exam type: `WEEKLY`, `MONTHLY`
  - Wrong reason tag: `VOCAB`, `EVIDENCE`, `INFERENCE`, `CARELESS`, `TIME`
- Content typeTag taxonomy (canonical, frozen):
  - Source of truth: `backend/shared/contracts/content_type_tags.json`
  - Listening:
    - `L_GIST`, `L_DETAIL`, `L_INTENT`, `L_RESPONSE`, `L_SITUATION`, `L_LONG_TALK`
  - Reading:
    - `R_MAIN_IDEA`, `R_DETAIL`, `R_INFERENCE`, `R_BLANK`, `R_ORDER`, `R_INSERTION`, `R_SUMMARY`, `R_VOCAB`
  - Legacy numeric aliases are compatibility-only (import/migration):
    - `L1 -> L_GIST`, `L2 -> L_DETAIL`, `L3 -> L_INTENT`
    - `R1 -> R_MAIN_IDEA`, `R2 -> R_DETAIL`, `R3 -> R_INFERENCE`
  - New write paths must reject legacy numeric tags and store canonical semantic tags only.
- Report schema:
  - Versioned, strict-guarded
  - Current frontend export target: `schemaVersion = 5`
  - Backward import compatibility required for v1~v5 payloads
  - v5 coverage:
    - `days`
    - `vocabQuiz`
    - `vocabBookmarks`
    - `customVocab.lemmasById`
    - `mockExams.weekly`
    - `mockExams.monthly`
- Composition invariants:
  - Daily: 3 listening + 3 reading
  - Weekly: 10 listening + 10 reading
  - Monthly: 17 listening + 28 reading
- Security/data constraints:
  - Export/import payload must never include copyrighted content text
  - IDs/metadata-only rule must be preserved

## F. Backend Phase-1 Scope

- Authentication
- Parent-child link service
- Sync event ingestion/pipeline
- Report aggregation service
- Content bank schema and APIs
- Mock exam blueprint/publish workflow

## G. Baseline Revision

- Frontend baseline commit: `f3e2956e868d2b5c19a7ee383b460f10db764460`
- CI baseline:
  - Flutter CI green
  - Android smoke green
  - iOS smoke green
  - Run: https://github.com/JH-Lab-cs/Resol-routine/actions/runs/22515570517

## H. Out of Scope for Backend Phase-1

- Real-time sync
- Teacher/admin public console
- Final billing production rollout
- AI auto-publish without human review
- Full content authoring UI

## I. Parent-Child Linking Policy (Phase-1 Default)

- Cardinality:
  - One parent can link up to 5 children.
  - One child can link up to 2 parents.
- Invite code:
  - 6-digit code.
  - One-time use.
  - Expiration: 10 minutes.
  - Plain-text storage is forbidden. Store only a secure hash.
  - Verification attempts are limited to 5 per 10 minutes per parent+IP.
  - Verification attempts are also limited to 5 per 10 minutes per invite_code+IP.
  - Device-based throttling must be enabled when `device_id` exists.
- Linking behavior:
  - Parent code entry links immediately in phase-1.
  - Student approval step is out of phase-1 scope.
  - Every link/unlink action must be audit-logged.
- Re-link/unlink:
  - Reusing an already-consumed code is rejected.
  - Unlink must preserve historical study/report data.
  - Re-link after unlink requires a new one-time code.

## J. Sync Model

- Mobile uploads event-level study results, not only final report snapshots.
- Server aggregates parent-facing reports from stored events.
- Export/import JSON remains dev-only QA path before backend rollout.
- `study_events` is append-only.
- Enforce `UNIQUE(student_id, idempotency_key)` for replay-safe ingestion.
- Report snapshots are derived aggregates, never source-of-truth records.
- Required common event fields:
  - `event_type`
  - `schema_version`
  - `device_id`
  - `occurred_at_client`
  - `received_at_server`
  - `idempotency_key`

## K. Content Lifecycle

- Draft generation
- Validation
- Human review
- Publish
- Client consumption
- Lifecycle enum is intentionally minimal:
  - `DRAFT`
  - `PUBLISHED`
  - `ARCHIVED`
- Validation/review are trace fields, not additional lifecycle enum states:
  - `validator_version`
  - `validated_at`
  - `reviewer_identity`
  - `reviewed_at`
- Publish gate:
  - Publish is allowed only when validation/review trace fields are present and required content checks pass.
- Terms like `VALIDATED`, `IN_REVIEW`, and `APPROVED` are operational checkpoints only.
  They must not be treated as DB lifecycle enum values.
- Mock exam revision archive audit fields are stored in `metadata_json` (no dedicated archive columns).
- For DB state checks, `lifecycle_status` is the single source of truth.
- Auto-publish is forbidden in phase-1.

## L. Mock Exam Assembly Rules

- Weekly and monthly mock exams are assembled server-side and published.
- The app consumes published sets, not ad-hoc runtime generation.
- Assembly must preserve:
  - track constraints
  - skill counts
  - type diversity
  - deterministic period keys

## M. Fixed Security/Operational Policy Values

- Auth/session:
  - Access token: JWT, 15 minutes
  - Refresh token: opaque random token (>= 256-bit entropy), 30 days
  - Refresh token storage: hash-only in DB
  - Refresh token rotation: required
  - Refresh token reuse detection: required
  - Device-scoped revoke support: required (`device_id`, `revoked_at`, `expires_at`)
  - Refresh token persistence model (required fields):
    - `id`
    - `user_id`
    - `device_id`
    - `token_hash`
    - `family_id`
    - `issued_at`
    - `expires_at`
    - `rotated_at`
    - `revoked_at`
    - `replaced_by_token_id`
    - `reuse_detected_at`
    - `ip`
    - `user_agent`
- Storage:
  - Cloudflare R2 bucket must stay private
  - File access must use signed URL or server proxy
  - Default signed URL TTL:
    - Upload: 5 minutes
    - Download: 5 minutes (max 10 minutes only for controlled cases)
  - MIME/type allowlist validation is required
  - Object key paths must not use raw user input
  - TTS asset generation is fingerprint-idempotent; identical successful requests must not create a second asset unless `forceRegen=true`
- Redis:
  - Allowed uses: Celery broker/result, rate-limit, invite throttling, cache
  - Forbidden uses: source-of-truth persistence, public exposure, unauthenticated access
  - Network policy: private network only; TLS/auth enabled in production
- Time policy:
  - DB timestamps must be stored in UTC.
  - `dayKey`/`weekKey`/`periodKey` boundary calculations must use Asia/Seoul.
  - Parent/student report display timestamps must use KST.

## Quick Start References

- Product/source-of-truth spec:
  - `docs/spec.md`
- Agent/development rules:
  - `AGENTS.md`
- Operations and CI/release rules:
  - `docs/operations.md`
