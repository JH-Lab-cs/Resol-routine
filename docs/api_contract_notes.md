# API Contract Notes (Pre-OpenAPI)

This note captures frontend-backend contracts that must remain stable while formal OpenAPI is prepared.

## Enum Contracts

- Track: `M3`, `H1`, `H2`, `H3`
- Skill: `LISTENING`, `READING`
- MockExamType: `WEEKLY`, `MONTHLY`
- WrongReasonTag: `VOCAB`, `EVIDENCE`, `INFERENCE`, `CARELESS`, `TIME`

## Content TypeTag Taxonomy Contract

- Single source of truth file:
  - `backend/shared/contracts/content_type_tags.json`
- Canonical type tags are semantic tags:
  - Listening:
    - `L_GIST`, `L_DETAIL`, `L_INTENT`, `L_RESPONSE`, `L_SITUATION`, `L_LONG_TALK`
  - Reading:
    - `R_MAIN_IDEA`, `R_DETAIL`, `R_INFERENCE`, `R_BLANK`, `R_ORDER`, `R_INSERTION`, `R_SUMMARY`, `R_VOCAB`
- Legacy numeric tags remain import-compatible only during migration:
  - `L1 -> L_GIST`
  - `L2 -> L_DETAIL`
  - `L3 -> L_INTENT`
  - `R1 -> R_MAIN_IDEA`
  - `R2 -> R_DETAIL`
  - `R3 -> R_INFERENCE`
- New backend-generated content and normalized frontend storage must use canonical semantic tags.
- New write paths must reject legacy numeric tags.

## Content Lifecycle Contract

- Lifecycle status enum is fixed and minimal:
  - `DRAFT`
  - `PUBLISHED`
  - `ARCHIVED`
- Validation/review progression is represented by trace fields, not extra enum states:
  - `validator_version`
  - `validated_at`
  - `reviewer_identity`
  - `reviewed_at`
- Publish is allowed only when trace-field gates are satisfied.
- `VALIDATED`, `IN_REVIEW`, `APPROVED` are process labels only, not lifecycle enum values.
- Mock exam revision archive audit fields are stored in `metadata_json` (no dedicated archive columns).
- DB lifecycle state judgment must rely on `lifecycle_status` only.

## Composition Contracts

- Daily: 6 fixed items (`LISTENING` x3 + `READING` x3)
- Weekly mock: 20 fixed items (`LISTENING` x10 + `READING` x10)
- Monthly mock: 45 fixed items (`LISTENING` x17 + `READING` x28)

## Report Schema Contract

- Current export target: `schemaVersion = 5`
- Import compatibility required for v1~v5 during rollout window
- v5 fields in active use:
  - `days`
  - `vocabQuiz`
  - `vocabBookmarks`
  - `customVocab.lemmasById`
  - `mockExams.weekly`
  - `mockExams.monthly`

## Security/Data Handling Contract

- IDs/metadata only in exported/imported payloads
- Never include copyrighted content text:
  - prompts/options/passages/scripts/explanations
  - vocab meaning/example text
- Hidden/bidi/zero-width unicode validation must be enforced on user-controlled fields

## TTS Contract

- TTS generation is limited to `LISTENING` + `DRAFT` content revisions.
- `POST /internal/ai/tts/jobs` is create-only; if an identical successful request fingerprint already exists and `forceRegen=false`, the request is rejected instead of creating a duplicate asset.
- `POST /internal/ai/tts/revisions/{revision_id}/ensure-audio` remains the idempotent no-op path when audio is already linked.

## Sync Contract Direction

- Backend ingest unit is event-level results, not only final report snapshots
- Parent report views must be server-aggregated from ingested events

## Parent Feature Rollout Contract

- Before backend child-link rollout:
  - parent auto-sync report is hidden on user path
  - file import/export remains dev-only QA path
