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
- Local vocab metadata now includes:
  - `sourceTag`
  - `targetMinTrack`
  - `targetMaxTrack`
  - `difficultyBand`
  - `frequencyTier`
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
- Content revision archive audit fields are stored in `metadata_json.archiveAudit` (no dedicated archive columns).
- Reviewer/ops tooling uses direct revision lookup via `GET /internal/content/revisions/{revision_id}`.
- Reviewer draft listing supports track/skill/typeTag filters plus pagination.
- For DB state checks, `lifecycle_status` is the single source of truth.
- Auto-publish is forbidden in phase-1.

## K-1. Published Content Delivery

- The app must consume backend-authored content from `PUBLISHED` revisions only.
- Public delivery endpoints:
  - `GET /public/content/units`
  - `GET /public/content/units/{revision_id}`
  - `GET /public/content/sync`
- Public list payload is lightweight:
  - `unitId`
  - `revisionId`
  - `track`
  - `skill`
  - `typeTag`
  - `difficulty`
  - `publishedAt`
  - `hasAudio`
- Public detail payload is canonical and full-fidelity:
  - READING: `bodyText`, question/options, answer/explanation metadata
  - LISTENING: `transcriptText`, `ttsPlan`, audio asset payload when available
- Delta sync contract:
  - `GET /public/content/sync` is the primary app sync surface.
  - Primary cursor is opaque and ordered by `(cursor_published_at, cursor_revision_id)`.
  - `GET /public/content/units?changedSince=...` remains compatibility/debug only.
  - Sync response splits:
    - `upserts`
    - `deletes`
    - `nextCursor`
    - `hasMore`
- Tombstone contract:
  - `content_sync_events` stores append-only client sync events.
  - `UPSERT` means the revision should exist in client cache.
  - `DELETE` means the revision must be removed or invalidated in client cache.
  - Delete reasons:
    - `ARCHIVED`
    - `REPLACED`
    - `UNPUBLISHED`
- Audio delivery contract:
  - audio stays in private R2 only
  - signed URL appears only on detail responses
  - default signed URL TTL is 5 minutes
  - signed URL cache must be treated separately from payload cache

## K-2. Local Dev/QA Content Readiness

- Local PostgreSQL verification is supported without Render/prod.
- Seed/audit tools:
  - `backend/tools/seed_dev_content.py`
  - `backend/tools/content_readiness_audit.py`
  - `backend/tools/reviewer_ops.py backfill-plan --json`
  - `backend/tools/reviewer_ops.py backfill-enqueue --json`
  - `backend/tools/reviewer_ops.py batch-validate --json`
  - `backend/tools/reviewer_ops.py batch-review --json`
  - `backend/tools/reviewer_ops.py batch-publish --json --confirm`
- Dev/QA seed intent:
  - sample published Daily candidate pool by track
  - sample weekly/monthly mock drafts for local verification
  - not a launch-readiness production bank snapshot
- Vocabulary banding metadata is currently seeded through the local app starter pack,
  not through backend PostgreSQL tables.
- Readiness policy is frozen in code and audit output:
  - Daily service-ready:
    - published count per skill >= `21`
    - listening diversity >= `4`
    - reading diversity >= `6`
    - average difficulty must stay close to the track target range
  - Weekly service-ready:
    - listening `10`
    - reading `10`
    - listening diversity >= `3`
    - reading diversity >= `4`
  - Monthly service-ready:
    - listening `17`
    - reading `28`
    - listening diversity >= `4`
    - reading diversity >= `6`
- Backfill planning is CLI-first and cost-capped:
  - default mode is dry-run
  - execution requires `backfill-enqueue --execute`
  - priority order is `Daily -> Weekly -> Monthly`

## K-3. Hard TypeTag Model Selection Policy

- Default content generation model remains `gpt-5-mini`.
- Hard-deficit typeTags must go through typeTag-specific hardened prompts first.
- Fallback evaluation is allowed only for hard-deficit typeTags and only when
  the comparison metric is `publishable item per dollar`.
- Current approved fallback tags:
  - `L_LONG_TALK -> gpt-4.1-mini`
  - `R_INSERTION -> gpt-4.1-mini`
- Current non-approved fallback tags:
  - `L_RESPONSE`
- `L_RESPONSE` no longer uses the generic canonical generation path.
  It uses:
  - prompt template `content-v1-listening-response-skeleton`
  - generation mode `L_RESPONSE_SKELETON`
  - compiler version `l-response-compiler-v1`
  - deterministic server-side compilation for stem/options/answerKey/transcript sentence ids/evidence ids
- `gpt-5.4` is explicitly out of scope for the current backfill policy.
  - `maxTargetsPerRun` and `maxCandidatesPerRun` cap each AI generation batch
  - `estimatedCostUsd` must stay within `AI_CONTENT_MAX_ESTIMATED_COST_USD`
  - provider/model/template validation happens before enqueue
  - duplicate active deficit signatures are skipped instead of enqueued twice
  - real provider env for content backfill:
    - `AI_CONTENT_PROVIDER`
    - `AI_CONTENT_MODEL`
    - `AI_CONTENT_API_KEY`
    - `AI_CONTENT_PROMPT_TEMPLATE_VERSION`
    - `AI_CONTENT_MAX_TARGETS_PER_RUN`
    - `AI_CONTENT_MAX_CANDIDATES_PER_RUN`
    - `AI_CONTENT_MAX_ESTIMATED_COST_USD`
    - `AI_CONTENT_DEFAULT_DRY_RUN`
- Reviewer batch operations remain human-controlled:
  - AI generation creates DRAFT only
  - validate/review/publish are done explicitly through batch ops commands
  - batch filters support:
    - `--track`
    - `--skill`
    - `--type-tag`
    - `--difficulty-min`
    - `--difficulty-max`
    - `--limit`
    - `--source`
    - `--generation-job-id`
  - controlled backfill drafts should be filtered with:
    - `source = content_readiness_backfill`
    - optional `generationJobId`
- Live smoke status for `L_RESPONSE`:
  - `gpt-5-mini` succeeded with the dedicated skeleton compiler path
  - batch validate/review/publish completed successfully
  - public list/detail/sync delivery exposure was verified
  - fallback remains disabled unless a later regression reopens the issue
- Frozen vocabulary banding policy:
  - see `docs/vocab_banding_policy.md`

## K-3. B3.4 Content Sync Readiness Gate

- `B3.4` (published content sync) may proceed only when the minimum gate holds.
- Frozen minimum gate:
  - Daily:
    - every track is at least `WARNING`
    - `H2` / `H3` being `READY` is preferred, not mandatory
    - `M3` / `H1` deficits must have an explicit backfill plan + publish queue
  - Mock:
    - `H2 weekly` must be `READY`
    - `H3 weekly/monthly` must be `READY`
    - `M3` / `H1` deficits must have an explicit backfill plan
  - Vocab:
    - metadata fields exist
    - each track band has a non-empty eligible pool
    - backend catalog may still be absent if local policy remains the source of truth
- Current audit output exposes this as `b34ContentSyncGate`.

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
