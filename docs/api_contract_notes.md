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
- Content revision archive audit fields are stored in `metadata_json.archiveAudit`.
- DB lifecycle state judgment must rely on `lifecycle_status` only.
- Reviewer direct lookup API:
  - `GET /internal/content/revisions/{revision_id}`
- Reviewer draft listing API:
  - `GET /internal/content/revisions`
  - Supported filters: `status`, `track`, `skill`, `typeTag`, `createdAfter`, `createdBefore`
  - Pagination: `page`, `pageSize`

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

## Vocabulary Banding Contract

- Backend vocabulary banding metadata is now bootstrapped into
  `vocab_catalog_entries` and is the canonical source of truth.
- Pre-B3 and pre-B3.4 app flows may still read local `vocab_master` metadata as
  a compatibility source until backend delivery is wired in.
- Required metadata fields:
  - `sourceTag`
  - `targetMinTrack`
  - `targetMaxTrack`
  - `difficultyBand`
  - optional `frequencyTier`
- Frozen source tags:
  - `CSAT`
  - `SCHOOL_CORE`
  - `USER_CUSTOM`
- Bootstrap seed/import excludes `USER_CUSTOM`.
- Backend bootstrap currently uses:
  - `assets/content_packs/starter_pack.json`
  - `backend/shared/seed/vocab_catalog_seed.json`
- Frozen progression policy is documented in `docs/vocab_banding_policy.md`.
- Adaptive/user-specific vocab selection is still post-B3 and must not be treated
  as implemented by this contract.

## Controlled Content Backfill Contract

- Readiness backfill reuses the B2.1 AI content generation pipeline.
- Controlled execution only:
  - planner output is dry-run by default
  - real enqueue requires `backfill-enqueue --execute`
  - auto-publish is forbidden
- Required provider contract for content backfill:
  - `AI_CONTENT_PROVIDER`
  - `AI_CONTENT_MODEL`
  - `AI_CONTENT_API_KEY`
  - `AI_CONTENT_PROMPT_TEMPLATE_VERSION`
- Budget guard contract:
  - `maxTargetsPerRun`
  - `maxCandidatesPerRun`
  - `estimatedProviderCalls`
  - `estimatedPromptTokens`
  - `estimatedOutputTokens`
  - `estimatedCostUsd`
  - `estimatedCostUsd` must not exceed `AI_CONTENT_MAX_ESTIMATED_COST_USD`
- Priority order is fixed:
  1. `DAILY_READINESS_DEFICIT`
  2. `WEEKLY_READINESS_DEFICIT`
  3. `MONTHLY_READINESS_DEFICIT`
- Duplicate active deficit signatures must be skipped rather than enqueued twice.
- Traceability requirements:
  - `source = content_readiness_backfill`
  - originating deficit plan
  - provider/model/template version
  - prompt/response/candidate/validation artifact keys
  - estimated cost summary
- Reviewer batch operations can target backfill drafts using:
  - `source = content_readiness_backfill`
  - `generationJobId = <uuid>`
  - publish remains explicit and human-confirmed only

## Published Content Delivery Contract

- The app consumes backend content through public published-revision delivery only:
  - `GET /public/content/units`
  - `GET /public/content/units/{revision_id}`
  - `GET /public/content/sync`
- Public delivery must exclude `DRAFT` and `ARCHIVED` revisions.
- `typeTag` in delivery payloads must always be canonical semantic taxonomy values.
- List endpoint contract:
  - `track` required
  - optional filters: `skill`, `typeTag`, `changedSince`
  - pagination: `page`, `pageSize`
  - delta sync cursor: `nextChangedSince`
  - list payload is summary-only (no full body/transcript text)
- Detail endpoint contract:
  - returns full canonical payload for a single `PUBLISHED` revision
  - `LISTENING` payload may include an audio signed URL
  - `READING` payload includes full body/question/explanation fields
- Delta sync rules:
  - `GET /public/content/sync` is the primary client sync contract.
  - `changedSince` on `GET /public/content/units` remains compatibility/debug only, not the primary cursor.
  - Primary sync cursor is opaque and ordered by `(cursor_published_at ASC, cursor_revision_id ASC)`.
  - The tuple rule is:
    - `cursor_published_at > last_published_at`
    - or `cursor_published_at = last_published_at` and `cursor_revision_id > last_revision_id`
  - This prevents same-timestamp page-boundary omissions.
  - `nextCursor` is the value clients must persist for the next sync call.
- Tombstone rules:
  - `content_sync_events` is append-only and client-facing only.
  - `UPSERT` is emitted when a revision becomes public-visible.
  - `DELETE` is emitted when a revision is removed from public-visible state.
  - `DELETE.reason` is one of:
    - `ARCHIVED`
    - `REPLACED`
    - `UNPUBLISHED`
  - App sync must treat `DELETE` as cache removal/invalidation.
- Signed URL rules:
  - private bucket only
  - included on detail responses only
  - default TTL: 5 minutes
- Cache rules:
  - App cache identity is `revisionId`.
  - `unitId` is used to understand replacement lineage, not as the primary cache key.
  - Signed audio URLs are never durable cache keys; they must be re-issued and treated separately from payload cache.

## Sync Contract Direction

- Backend ingest unit is event-level results, not only final report snapshots
- Parent report views must be server-aggregated from ingested events

## Parent Feature Rollout Contract

- Before backend child-link rollout:
  - parent auto-sync report is hidden on user path
  - file import/export remains dev-only QA path
