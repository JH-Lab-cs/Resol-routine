# PRE-B3 Audit And Policy Freeze

Last updated: 2026-03-15

## Scope

This document freezes the pre-B3 audit baseline for:

- Daily content coverage
- Vocabulary bank suitability
- Weekly/monthly mock assembly suitability
- Daily order policy
- Adaptive selection design notes

It is intentionally an audit and policy document. It does not change user-facing
product behavior by itself.

## Calibration Gate Baseline

- `schema valid` is no longer treated as sufficient for publishability
- every publish attempt now runs a track calibration evaluation
- `M3/H1`
  - warning mode is limited by a warning budget
  - warning count `<= 1` may still publish with reviewer approval
  - warning count `>= 2` sets `overrideRequired = true`
  - `length_too_short` and `direct_clue_too_strong` are immediate block reasons
- `H2/H3`
  - hard typeTags are fail-close
  - current fail-close set:
    - `R_INSERTION`
    - `R_ORDER`
    - `R_SUMMARY`
    - `L_SITUATION`
    - `L_LONG_TALK`
- calibration metadata is stored in revision `metadata_json`
- quality gate metadata is now also stored:
  - `qualityGateVersion`
  - `overrideRequired`
- a gold anchor regression set exists at:
  - `backend/tests/fixtures/calibration_gold_set.json`
- after `B2.6.18`, inventory depth matters only when the generated items also
  clear the calibration and quality gates

## B3.4 Minimum Gate

The frozen minimum gate for `B3.4` content sync is:

- Daily
  - every track must be at least `WARNING`
  - `H2` / `H3` `READY` is preferred, not mandatory
  - `M3` / `H1` must have an explicit backfill plan and publish queue
- Mock
  - `H2 weekly` must be `READY`
  - `H3 weekly/monthly` must be `READY`
  - `M3` / `H1` must have an explicit deficit plan
- Vocab
  - metadata must exist
  - each track band must have a non-empty eligible pool
  - backend vocab catalog must be seeded and treated as the canonical source

## Audit Inputs

### Frontend-local content source

- `assets/content_packs/starter_pack.json`
- Current app bootstrap still relies on the starter pack for local content and
  vocabulary seeding.

### Backend-published content source

- Published delivery/sync contracts exist.
- Mock assembly requires `PUBLISHED` + validated + reviewed content units.
- The repository does not contain a committed published content bank snapshot.
- Backend tests create published rows ephemerally, but those fixtures are not a
  service inventory and must not be treated as a production-ready bank.

## 1. Daily Coverage Audit

### Current committed coverage matrix

The starter pack currently contains 24 total questions:

- 12 listening
- 12 reading
- 4 tracks x 6 questions each

Legacy numeric tags in the starter pack are normalized to canonical semantic
tags at read/write boundaries.

| Track | Skill | Count | Difficulty buckets | Canonical type tags |
| --- | --- | ---: | --- | --- |
| M3 | LISTENING | 3 | 1 x1, 2 x2 | `L_GIST`, `L_DETAIL`, `L_INTENT` |
| M3 | READING | 3 | 1 x1, 2 x2 | `R_MAIN_IDEA`, `R_DETAIL`, `R_INFERENCE` |
| H1 | LISTENING | 3 | 2 x1, 3 x2 | `L_GIST`, `L_DETAIL`, `L_INTENT` |
| H1 | READING | 3 | 2 x1, 3 x2 | `R_MAIN_IDEA`, `R_DETAIL`, `R_INFERENCE` |
| H2 | LISTENING | 3 | 3 x1, 4 x2 | `L_GIST`, `L_DETAIL`, `L_INTENT` |
| H2 | READING | 3 | 3 x1, 4 x2 | `R_MAIN_IDEA`, `R_DETAIL`, `R_INFERENCE` |
| H3 | LISTENING | 3 | 4 x1, 5 x2 | `L_GIST`, `L_DETAIL`, `L_INTENT` |
| H3 | READING | 3 | 4 x1, 5 x2 | `R_MAIN_IDEA`, `R_DETAIL`, `R_INFERENCE` |

### Can Daily 3+3 be formed today?

Yes, but only at the narrowest possible level.

Per track, the starter pack provides:

- exactly 3 listening questions
- exactly 3 reading questions

That means the app can assemble one deterministic Daily set per track, but it
has no real redundancy, no rotation buffer, and no adaptive headroom.

### Coverage holes

#### Listening

- Missing `L_RESPONSE`
- Missing `L_SITUATION`
- Missing `L_LONG_TALK`

#### Reading

- Missing `R_BLANK`
- Missing `R_ORDER`
- Missing `R_INSERTION`
- Missing `R_SUMMARY`
- Missing `R_VOCAB`

#### Difficulty resilience

- No track has a broad 1..5 pool inside the same track/skill bucket.
- Each track is effectively pinned to a narrow band:
  - M3: 1..2
  - H1: 2..3
  - H2: 3..4
  - H3: 4..5

This is acceptable for a dev/demo starter pack, but not enough for a live
service that needs repetition control, quality fallback, or future adaptive
selection.

### Recommended minimum threshold for live Daily service

Recommended per track:

- LISTENING: at least 21 published items
- READING: at least 21 published items

Reasoning:

- Daily consumes 3 listening + 3 reading per day.
- A 7-day rotation without immediate repetition requires 21 items per skill.

Recommended diversity floor per track:

- Listening: at least 4 canonical type tags represented
- Reading: at least 5 canonical type tags represented
- At least 2 difficulty buckets populated inside the target band for that track

### Daily readiness verdict

- Local starter-pack demo: `Serviceable for development only`
- Real service readiness: `Not sufficient`

Status: `NOT_READY`

## 2. Vocabulary Audit

### Current canonical vocabulary source

Backend canonical source:

- `vocab_catalog_entries`
- bootstrap sources:
  - `assets/content_packs/starter_pack.json`
  - `backend/shared/seed/vocab_catalog_seed.json`
- current backend catalog size: `31` curated rows
- sourceTag distribution:
  - `CSAT`: `15`
  - `SCHOOL_CORE`: `16`
- difficultyBand distribution:
  - `1`: `7`
  - `2`: `10`
  - `3`: `9`
  - `4`: `4`
  - `5`: `1`

Compatibility source that still exists until B3.4:

- local app `vocab_master`

Frozen backend metadata now includes:

- `source_tag`
- `target_min_track`
- `target_max_track`
- `difficulty_band`
- optional `frequency_tier`
- `catalog_key`
- `is_active`
- optional `source_metadata_json`

### Can the current structure support track-differentiated vocab selection?

Partially.

The current repository can support:

- SRS state
- bookmarking
- deterministic daily quiz ordering

The metadata needed to separate vocab by school level or exam target now exists
in the backend catalog. The remaining gap is depth, not schema.

### Proposed selection rule to freeze now

The long-term progression target is CSAT-oriented vocabulary.

Frozen rule for future implementation:

- M3: prioritize high-frequency foundational academic vocabulary
- H1: prioritize lower-band CSAT/core school vocabulary
- H2: prioritize mid-band CSAT vocabulary plus carry-over review
- H3: prioritize upper-band CSAT vocabulary plus spaced review of prior bands

### Additional metadata required

No additional metadata is required for the initial backend bootstrap. The
remaining requirement is more curated rows per band.

### Vocabulary readiness verdict

- Backend schema/policy: `Ready`
- Real grade-differentiated service depth: `Ready`
- Track usable counts:
  - `M3`: `24`
  - `H1`: `31`
  - `H2`: `30`
  - `H3`: `23`
Status: `READY`

## 3. Weekly/Monthly Mock Audit

### Required assembly targets

- Weekly: 10 listening + 10 reading
- Monthly: 17 listening + 28 reading

### Required backend source

Mock assembly only accepts content that is:

- `PUBLISHED`
- validated
- reviewed
- canonical taxonomy compliant

### What can be audited from the repository today?

The repository contains:

- backend mock assembly logic
- delivery contracts
- test fixtures that generate published rows in transient test databases

The repository does **not** contain:

- a committed published content inventory snapshot
- a durable track-by-track published bank export

Therefore, a true service suitability count for backend published mock assembly
cannot be certified from source control alone.

### Practical conclusion

Using only committed local content:

- each track has 3 listening + 3 reading items in the starter pack
- therefore weekly 10+10 is impossible
- therefore monthly 17+28 is impossible

Using backend-published content:

- audit is blocked by missing inventory snapshot
- repo evidence does not prove that any track currently has sufficient
  published-bank depth for weekly/monthly assembly

### Missing evidence required before B3 or early B3 integration

Need one of:

- a DB inventory export of published content by track/skill/typeTag/difficulty
- an audit script run against a staging DB with published rows

### Mock readiness verdict

- Weekly readiness by committed repo content: `Not sufficient`
- Monthly readiness by committed repo content: `Not sufficient`
- Backend published-bank readiness: `Not auditable from repo snapshot`

Status: `BLOCKED_BY_MISSING_PUBLISHED_BANK_INVENTORY`

## 4. Daily Order Policy Freeze

This policy is frozen here:

- Daily: User may choose `Listening first` or `Reading first`
- Weekly mock: fixed order
- Monthly mock: fixed order

Implementation status:

- Daily order preference is implemented in the app
- Weekly/monthly mock ordering remains fixed

Rationale:

- Daily is short-form practice and benefits from user control
- Weekly/monthly mock sets are exam-style flows and should keep deterministic,
  fixed ordering

## 5. Adaptive Selection Design Note

Implementation is explicitly out of scope for this ticket.

### Frozen design direction

Future Daily selection should prioritize:

1. unseen items
2. wrong items
3. stale items
4. target-difficulty fit
5. target exam-level fit

### Draft scoring formula

Example draft score:

`score = unseen_bonus + wrong_bonus + stale_bonus + difficulty_fit + track_fit - overexposure_penalty - recent_repeat_penalty`

Suggested starting weights:

- `unseen_bonus = +100` if exposure count is 0
- `wrong_bonus = +60 * wrong_weight`
- `stale_bonus = min(days_since_last_seen, 30) * 1.5`
- `difficulty_fit = +0..20`
- `track_fit = +0..15`
- `overexposure_penalty = exposure_count * 5`
- `recent_repeat_penalty = 40` if seen too recently for the same flow

### Required backend/app data contract

Adaptive selection needs at least:

- stable `questionId` / `revisionId`
- synced attempt history
- correctness
- attempted timestamp
- exposure count
- last seen timestamp
- wrong reason tags
- response time
- track
- skill
- canonical type tag
- difficulty

### Why this stays out of B3

Adaptive selection should not be implemented before B3 wiring because it
depends on:

- unified frontend/backend attempt history
- stable sync semantics
- cache invalidation guarantees

Recommended implementation phase:

- B3 after sync is stable, or
- B4 if adaptive scoring needs richer telemetry first

## 6. B3 Entry Gate: Blockers vs Non-Blockers

### Blockers

- Daily live-service coverage is too shallow for real content rotation
- Vocabulary bank is too small and lacks level metadata
- Backend published mock bank inventory is not available in-repo, so weekly and
  monthly readiness cannot be certified

### Non-blockers

- Daily order preference is already implemented and does not block B3
- Adaptive selection can remain design-only until sync contracts stabilize
- B2.5/B2.6 delivery and sync contracts are already good enough to support B3
  integration work once real content depth is present

## Final Verdict

Pre-B3 technical contract readiness is acceptable.

Pre-B3 content readiness is not yet service-complete.

Frozen judgment:

- API/sync contract readiness: `READY`
- Content depth readiness: `NOT_READY`
- Vocabulary progression readiness: `NOT_READY`
- Mock published-bank readiness: `BLOCKED`

Recommended interpretation:

- B3 can proceed for wiring/integration work
- B3 must not be treated as launch-readiness for content depth

## Appendix: B2.6.2 Local PostgreSQL Dev/QA Baseline

This appendix captures the local docker-compose + PostgreSQL verification path
added after the original pre-B3 audit.

Purpose:

- make Daily/mock readiness auditable from a local backend database
- provide deterministic dev/qa seed data
- keep launch-readiness judgment separate from seed-only verification

Local verification tools:

- `backend/tools/seed_dev_content.py`
- `backend/tools/content_readiness_audit.py`

Seed intent:

- `M3`, `H1`: Daily candidate coverage only
- `H2`: Daily coverage plus one weekly-ready published bank slice
- `H3`: Daily coverage plus one monthly-ready published bank slice
- weekly mock draft sample:
  - `track=H2`
  - `periodKey=2026W15`
- monthly mock draft sample:
  - `track=H3`
  - `periodKey=202603`

Interpretation:

- local dev/qa seed readiness demonstrates backend auditability and assembly
  behavior
- it does **not** certify production launch depth on its own

### Verified local seed result (2026-03-08)

`backend/tools/seed_dev_content.py --json`

- created published units: `107`
- skipped published units: `0`
- weekly mock sample created:
  - `track=H2`
  - `periodKey=2026W15`
  - status `SUCCEEDED`
- monthly mock sample created:
  - `track=H3`
  - `periodKey=202603`
  - status `SUCCEEDED`

### Verified local Daily readiness

From `backend/tools/content_readiness_audit.py --json` against local Postgres:

| Track | Listening total | Reading total | Daily readiness | Notes |
| --- | ---: | ---: | --- | --- |
| M3 | 6 | 6 | `WARNING` | Daily 3+3 is possible, but type diversity and live-service depth are below target |
| H1 | 8 | 8 | `WARNING` | Daily 3+3 is possible, but counts are below live threshold |
| H2 | 12 | 10 | `WARNING` | Daily 3+3 is possible, but listening/reading diversity is still narrow |
| H3 | 21 | 36 | `READY` | Meets the local dev/qa ready threshold for Daily |

Key coverage holes from the seeded bank:

- `M3`
  - listening missing: `L_RESPONSE`, `L_SITUATION`, `L_LONG_TALK`
  - reading missing: `R_BLANK`, `R_ORDER`, `R_INSERTION`, `R_SUMMARY`, `R_VOCAB`
- `H1`
  - listening missing: `L_SITUATION`, `L_LONG_TALK`
  - reading missing: `R_BLANK`, `R_ORDER`, `R_INSERTION`, `R_SUMMARY`
- `H2`
  - listening missing: `L_RESPONSE`, `L_SITUATION`, `L_LONG_TALK`
  - reading missing: `R_ORDER`, `R_INSERTION`, `R_SUMMARY`, `R_VOCAB`
- `H3`
  - listening missing: `L_RESPONSE`, `L_SITUATION`
  - reading missing: `R_SUMMARY`, `R_VOCAB`

### Verified local Mock readiness

From the same local audit run:

| Track | Weekly | Monthly | Verdict |
| --- | --- | --- | --- |
| M3 | `NOT_READY` | `NOT_READY` | blocked by insufficient published content |
| H1 | `NOT_READY` | `NOT_READY` | blocked by insufficient published content |
| H2 | `READY` | `NOT_READY` | weekly-ready slice only |
| H3 | `READY` | `READY` | both weekly/monthly-ready slice available |

Difficulty and diversity notes:

- `H2 weekly`
  - average difficulty: `2.9`
  - target range: `2.8 .. 3.6`
  - listening type diversity: `3`
  - reading type diversity: `4`
- `H3 monthly`
  - average difficulty: `3.5556`
  - target range: `3.3 .. 4.2`
  - listening type diversity: `4`
  - reading type diversity: `6`

Local conclusion:

- Daily auditability is now reproducible from local Postgres
- mock assembly readiness is now reproducible from local Postgres
- the seeded bank is suitable for dev/qa verification
- it is still intentionally narrower than a production content bank

## 9. B2.6.3 Readiness Backfill Policy

### Frozen service thresholds

- Daily
  - published count per skill >= `21`
  - listening typeTag diversity >= `4`
  - reading typeTag diversity >= `6`
  - average difficulty must stay inside the track target range closely enough
- Weekly
  - listening `10`
  - reading `10`
  - listening diversity >= `3`
  - reading diversity >= `4`
- Monthly
  - listening `17`
  - reading `28`
  - listening diversity >= `4`
  - reading diversity >= `6`
- Vocabulary
  - per-track eligible vocab rows >= `20`
  - required metadata:
    - `sourceTag`
    - `targetMinTrack`
    - `targetMaxTrack`
    - `difficultyBand`

### Backfill execution policy

- planner output is generated from published inventory only
- planner emits deficit rows with:
  - `track`
  - `skill`
  - `typeTag`
  - `difficultyMin`
  - `difficultyMax`
  - `requiredCount`
  - `reason`
- deficit reasons are frozen:
  - `DAILY_READINESS_DEFICIT`
  - `WEEKLY_READINESS_DEFICIT`
  - `MONTHLY_READINESS_DEFICIT`
  - `VOCAB_BANDING_DEFICIT`
- AI enqueue bridge reuses B2.1 content generation jobs
- auto-publish remains forbidden

### Cost control policy

- `backfill-plan` is dry-run by default
- real enqueue requires `backfill-enqueue --execute`
- batch budgets are explicit:
  - `maxTargetsPerRun`
  - `maxCandidatesPerRun`
- execution also checks:
  - provider configured
  - model configured
  - prompt template version configured
  - `estimatedCostUsd <= AI_CONTENT_MAX_ESTIMATED_COST_USD`
- priority order is fixed:
  1. Daily readiness deficits
  2. Weekly readiness deficits
  3. Monthly readiness deficits
- duplicate active deficit keys are skipped during enqueue so the same
  track/skill/typeTag/difficulty deficit is not queued twice

### Current backfill interpretation from the seeded local bank

- `M3`
  - Daily: backfill required
  - Weekly: backfill required
  - Monthly: backfill required
- `H1`
  - Daily: backfill required
  - Weekly: backfill required
  - Monthly: backfill required
- `H2`
  - Daily: backfill required
  - Weekly: ready from the local seed
  - Monthly: backfill required
- `H3`
  - Daily: ready from the local seed
  - Weekly: ready from the local seed
  - Monthly: ready from the local seed
  - Vocabulary: still not ready by service threshold

### Reviewer ops batch flow

- `reviewer_ops.py backfill-plan --json`
  - inspect deficit rows and estimated AI job cost
- `reviewer_ops.py backfill-enqueue --execute --json`
  - create AI content generation jobs from the planner output
- `reviewer_ops.py batch-validate --validator ... --json`
- `reviewer_ops.py batch-review --reviewer ... --json`
- `reviewer_ops.py batch-publish --confirm --json`

Integration tests now verify that publishing the final missing Daily draft can
move a track from `WARNING` to `READY`, so the backfill -> human review ->
publish loop is covered before B3 wiring starts.

## 10. B2.6.6 Live Provider Smoke Baseline

The local backend now has a verified live-provider smoke path using:

- provider: `openai`
- model: `gpt-5-mini`
- prompt template: `content-v1`
- execution mode: controlled backfill only

### Verified READING live smoke

The READING path already completed end-to-end with:

- live provider candidate generation
- artifact persistence
- draft materialization
- batch validate / review / publish
- public list / detail / sync visibility

Observed `M3 READING` change from the published bank:

- total published reading items: `6 -> 8`
- `R_BLANK`: `0 -> 2`

### Verified LISTENING live smoke

The LISTENING path is also now closed end-to-end with the same provider/model:

- live provider candidate generation
- artifact persistence
- draft materialization
- batch validate / review / publish
- public list / detail / sync visibility

Observed `M3 LISTENING` change from the published bank:

- total published listening items: `6 -> 7`
- `L_DETAIL`: `2 -> 3`

What this verifies:

- real-provider generation works for both `READING` and `LISTENING`
- reviewer source filtering by `content_readiness_backfill` and generation job id
  is strong enough for batch promotion
- publish results are reflected in public delivery contracts and readiness audit

### LISTENING payload / TTS compatibility note

The published LISTENING smoke revision is valid even when:

- `transcriptText` is present
- `ttsPlan` is present
- `asset` is still `null`

This is acceptable for the current public delivery contract because:

- audio signed URLs remain optional until the TTS pipeline attaches an asset
- the LISTENING payload shape remains stable for later B2.3 integration

Practical interpretation:

- live generation-path risk is now closed for both `READING` and `LISTENING`
- inventory depth risk is still open for `M3`, `H1`, and parts of `H2`

## 11. B2.6.7 Controlled Inventory Backfill Execution

This run used the same controlled execution policy as B2.6.6/B2.6.6a:

- provider: `openai`
- model: `gpt-5-mini`
- prompt template: `content-v1`
- max targets per run: `1`
- max candidates per run: `2`

The goal was not bulk generation. The goal was to reduce the next highest
priority Daily deficits with very small live batches and then immediately
validate, review, publish, and re-audit.

### Successful batches

1. `M3 / LISTENING / L_GIST / difficulty 1`
   - generation job: `b55ddb7f-7bd5-453b-b194-a21a38308ca3`
   - published revision: `378d429b-6361-4bde-acd5-40de52595788`
   - effect:
     - `M3 LISTENING total: 7 -> 8`
     - `L_GIST: 2 -> 3`

2. `H1 / LISTENING / L_DETAIL / difficulty 2`
   - generation job: `fed0db38-c998-43b0-9be6-709a5a52e70d`
   - published revision: `653e6ec5-a46f-4197-a935-bad5a52b16e4`
   - effect:
     - `H1 LISTENING total: 8 -> 9`
     - `L_DETAIL: 2 -> 3`

### Failed live batches

The following small runs reached the real provider and worker path, but failed
at generation validation with `OUTPUT_SCHEMA_INVALID`:

- `M3 / LISTENING / L_LONG_TALK / difficulty 1`
- `M3 / LISTENING / L_RESPONSE / difficulty 1`
- `M3 / READING / R_INSERTION / difficulty 1`
- `M3 / READING / R_MAIN_IDEA / difficulty 1`
- `H1 / READING / R_BLANK / difficulty 2`
- `H2 / READING / R_INSERTION / difficulty 3`

Interpretation:

- `gpt-5-mini` is stable enough for some small `LISTENING` count-focused deficits
  (`L_GIST`, `L_DETAIL`)
- the same model is still unstable for several missing-type deficits, especially
  `R_INSERTION` and `L_LONG_TALK`
- this is no longer a pipeline correctness problem; it is a model/typeTag fit
  problem for low-cost controlled backfill

### Before / after readiness summary

- `M3`
  - Daily: `WARNING -> WARNING`
  - Weekly: `NOT_READY -> NOT_READY`
  - Monthly: `NOT_READY -> NOT_READY`
  - published counts:
    - LISTENING `7 -> 8`
    - READING `8 -> 8`

- `H1`
  - Daily: `WARNING -> WARNING`
  - Weekly: `NOT_READY -> NOT_READY`
  - Monthly: `NOT_READY -> NOT_READY`
  - published counts:
    - LISTENING `8 -> 9`
    - READING `8 -> 8`

- `H2`
  - Daily: `WARNING -> WARNING`
  - Weekly: `READY -> READY`
  - Monthly: `NOT_READY -> NOT_READY`
  - published counts:
    - LISTENING `13 -> 13`
    - READING `10 -> 10`

- `H3`
  - unchanged

### Remaining deficit interpretation after this run

- `M3`
  - still needs additional Daily count
  - still missing `L_RESPONSE`, `L_SITUATION`, `L_LONG_TALK`
  - still missing `R_ORDER`, `R_INSERTION`, `R_SUMMARY`, `R_VOCAB`

- `H1`
  - still needs additional Daily count
  - still missing `L_SITUATION`, `L_LONG_TALK`
  - still missing `R_BLANK`, `R_ORDER`, `R_INSERTION`, `R_SUMMARY`

- `H2`
  - Weekly remains serviceable
  - Monthly remains blocked by reading-side inventory and diversity

### Practical next step

For the next controlled run, the evidence now supports:

1. keep using very small batches
2. keep `Daily` ahead of `Weekly/Monthly`
3. prefer proven schema-friendly deficits first
4. treat `R_INSERTION`, `L_LONG_TALK`, and similar harder typeTags as either:
   - a prompt-tuning follow-up, or
   - a model-selection follow-up (for example `gpt-4.1-mini`) before larger
     inventory fill

## 12. B2.6.8 Hard Deficit TypeTag Hardening and Fallback Evaluation

This evaluation kept the default generation model unchanged:

- default model: `gpt-5-mini`
- fallback candidate: `gpt-4.1-mini`
- excluded from this scope: `gpt-5.4`

The goal was not bulk inventory fill. The goal was to determine whether
hard-deficit typeTags should stay on the hardened default path or gain a
typeTag-specific fallback policy.

### Prompt and schema hardening now in effect

- hard typeTags use dedicated prompt template variants:
  - `content-v1-listening-longtalk`
  - `content-v1-listening-response-skeleton`
  - `content-v1-listening-situation`
  - `content-v1-reading-insertion`
  - `content-v1-reading-blank`
  - `content-v1-reading-order`
  - `content-v1-reading-summary`
  - `content-v1-reading-vocab`
- validator rules are stricter for hard tags:
  - options must remain unique
  - `answerKey` must stay in `A..E`
  - evidence ids must point to real sentences
  - LISTENING transcript / turn / sentence alignment is required
  - typeTag-specific field expectations are enforced before materialization

### Small A/B evaluation label

- evaluation label: `b2-6-8-ab-20260310125300`

### Observed A/B outcomes

1. `L_LONG_TALK`
   - `gpt-5-mini`
     - job: `2281cf76-9346-45c0-ad18-7f90a0049ab9`
     - status: `FAILED`
     - valid candidate rate: `0.0`
     - materialize success rate: `0.0`
     - publishable item rate: `0.0`
     - estimated cost USD: `0.002855`
   - `gpt-4.1-mini`
     - job: `78bec2c3-7374-4e05-93eb-f1210ab88caf`
     - status: `SUCCEEDED`
     - valid candidate rate: `1.0`
     - materialize success rate: `1.0`
     - publishable item rate: `1.0`
     - estimated cost USD: `0.002488`
     - publishable item per dollar: `401.92926`

2. `L_RESPONSE`
   - `gpt-5-mini`
     - job: `ffd2ab3f-3caf-421b-b1ae-60efeca0697b`
     - status: `FAILED`
     - valid candidate rate: `0.0`
     - materialize success rate: `0.0`
     - publishable item rate: `0.0`
     - estimated cost USD: `0.004155`
   - `gpt-4.1-mini`
     - job: `fbefc49f-bffb-43f2-9d8f-be546052185a`
     - status: `SUCCEEDED`
     - valid candidate rate: `0.0`
     - materialize success rate: `0.0`
     - publishable item rate: `0.0`
     - estimated cost USD: `0.003528`
   - interpretation:
     - the fallback candidate was still not publishable
     - fallback is not approved yet for this typeTag

3. `R_INSERTION`
   - `gpt-5-mini`
     - job: `e692933f-ce91-422a-b979-7c4c733c6a30`
     - status: `FAILED`
     - valid candidate rate: `0.0`
     - materialize success rate: `0.0`
     - publishable item rate: `0.0`
     - estimated cost USD: `0.002855`
   - `gpt-4.1-mini`
     - job: `687490e7-9ecf-4e9a-ae4b-da470ce21ade`
     - status: `SUCCEEDED`
     - valid candidate rate: `1.0`
     - materialize success rate: `1.0`
     - publishable item rate: `1.0`
     - estimated cost USD: `0.002488`
     - publishable item per dollar: `401.92926`

### Policy decision from the A/B

- default model remains `gpt-5-mini`
- approved fallback tags:
  - `L_LONG_TALK`
  - `R_INSERTION`
- not approved for fallback yet:
  - `L_RESPONSE`
- follow-up policy:
  - `L_RESPONSE` must be redesigned around a dedicated skeleton compiler before
    any fallback is reconsidered
- decision rule:
  - approve fallback only when the fallback path improves publishable item per
    dollar enough to justify the added model branch

### Practical inventory interpretation

The evaluation improved the published bank but did not change readiness labels:

- `M3 LISTENING`
  - `L_LONG_TALK` is no longer missing
  - still missing `L_RESPONSE`, `L_SITUATION`
- `M3 READING`
  - `R_INSERTION` is no longer missing
  - still missing `R_ORDER`, `R_SUMMARY`, `R_VOCAB`

So B2.6.8 closed the model-selection question for two hard tags, but it did not
finish the overall inventory-fill problem.

## 13. B2.6.9 Controlled Inventory Backfill Round 2

This round applied the B2.6.8 routing policy directly to real inventory fill:

- default model: `gpt-5-mini`
- approved hard-tag fallback:
  - `L_LONG_TALK -> gpt-4.1-mini`
  - `R_INSERTION -> gpt-4.1-mini`
- excluded from this run:
  - `L_RESPONSE`

All publishable candidates in this round came from the approved fallback path.

### Executed deficits

- `M3 / LISTENING / L_LONG_TALK / difficulty 1`
- `M3 / READING / R_INSERTION / difficulty 1`
- `H1 / READING / R_INSERTION / difficulty 2`
- `H1 / READING / R_INSERTION / difficulty 2`
- `H2 / LISTENING / L_LONG_TALK / difficulty 3`
- `H2 / READING / R_INSERTION / difficulty 3`

### Published revisions

Six fallback-routed candidates were materialized, validated, reviewed, and
published:

- `79dbf0cc-6a86-40a6-a444-416bd6549979`
  - model: `gpt-4.1-mini`
  - typeTag: `L_LONG_TALK`
  - track/skill: `M3 / LISTENING`
  - publishable item per dollar: `690.607735`
- `6485e33b-bb5c-4260-bbc3-832e01b9dd1e`
  - model: `gpt-4.1-mini`
  - typeTag: `R_INSERTION`
  - track/skill: `M3 / READING`
  - publishable item per dollar: `690.607735`
- `ee19fb3d-ed0c-4512-994d-5bf3862943a4`
  - model: `gpt-4.1-mini`
  - typeTag: `R_INSERTION`
  - track/skill: `H1 / READING`
  - publishable item per dollar: `401.92926`
- `9f3c58b6-266d-4123-8cae-27f68021588a`
  - model: `gpt-4.1-mini`
  - typeTag: `R_INSERTION`
  - track/skill: `H1 / READING`
  - publishable item per dollar: `401.92926`
- `5f11872a-cb8e-48a1-ad2a-4fd0295018f4`
  - model: `gpt-4.1-mini`
  - typeTag: `L_LONG_TALK`
  - track/skill: `H2 / LISTENING`
  - publishable item per dollar: `401.92926`
- `4607d75a-8317-47fd-8da5-55826bb71390`
  - model: `gpt-4.1-mini`
  - typeTag: `R_INSERTION`
  - track/skill: `H2 / READING`
  - publishable item per dollar: `283.446712`

### Before / after readiness summary

- `M3`
  - Daily: `WARNING -> WARNING`
  - Weekly: `NOT_READY -> WARNING`
  - Monthly: `NOT_READY -> NOT_READY`
  - published counts:
    - LISTENING `9 -> 10`
    - READING `9 -> 10`
  - practical effect:
    - `L_LONG_TALK` no longer missing
    - `R_INSERTION` no longer missing

- `H1`
  - Daily: `WARNING -> WARNING`
  - Weekly: `NOT_READY -> NOT_READY`
  - Monthly: `NOT_READY -> NOT_READY`
  - published counts:
    - LISTENING `9 -> 9`
    - READING `8 -> 10`
  - practical effect:
    - `R_INSERTION` no longer missing
    - reading type diversity `4 -> 5`

- `H2`
  - Daily: `WARNING -> WARNING`
  - Weekly: `READY -> READY`
  - Monthly: `NOT_READY -> NOT_READY`
  - published counts:
    - LISTENING `13 -> 14`
    - READING `10 -> 11`
  - practical effect:
    - `L_LONG_TALK` no longer missing
    - `R_INSERTION` no longer missing
    - listening type diversity `4 -> 5`
    - reading type diversity `4 -> 5`

- `H3`
  - unchanged

Interpretation:

- no Daily track changed label from `WARNING` to `READY`
- however `M3`, `H1`, and `H2` all improved numerically at the published-bank
  level
- `M3 weekly` improved from `NOT_READY` to `WARNING`
- the approved fallback policy materially increased publishable inventory

### Remaining deficits after round 2

- `M3`
  - listening missing: `L_RESPONSE`, `L_SITUATION`
  - reading missing: `R_ORDER`, `R_SUMMARY`, `R_VOCAB`
- `H1`
  - listening missing: `L_SITUATION`, `L_LONG_TALK`
  - reading missing: `R_BLANK`, `R_ORDER`, `R_SUMMARY`
- `H2`
  - listening missing: `L_SITUATION`
  - reading missing: `R_ORDER`, `R_SUMMARY`, `R_VOCAB`

### Round 2 policy conclusion

- the fallback policy is justified for:
  - `L_LONG_TALK`
  - `R_INSERTION`
- the default model remains `gpt-5-mini`
- `L_RESPONSE` remains excluded from fallback pending a dedicated generation redesign

## 14. B2.6.10 L_RESPONSE Dedicated Generation Redesign

`L_RESPONSE` now uses a dedicated generation mode instead of the generic
canonical content prompt.

### Dedicated mode

- prompt template: `content-v1-listening-response-skeleton`
- generation mode: `L_RESPONSE_SKELETON`
- compiler version: `l-response-compiler-v1`
- base model remains `gpt-5-mini`
- fallback remains disabled in this ticket

### Skeleton contract

The model must return only a response skeleton:

- `track`
- `difficulty`
- `typeTag = L_RESPONSE`
- `turns` (exactly 2)
- `responsePromptSpeaker`
- `correctResponseText`
- `distractorResponseTexts` (exactly 4)
- `evidenceTurnIndexes`
- `whyCorrectKo`
- `whyWrongKoByOption`

The model does **not** generate the final canonical stem, answer key, or
sentence ids.

### Deterministic compiler

The server now compiles the canonical payload deterministically:

- fixed stem:
  - `What is the most appropriate response to the last speaker?`
- fixed option placement:
  - `A = correct`
  - `B..E = distractors`
- fixed `answerKey`
- deterministic transcript text
- deterministic sentence ids
- deterministic `evidenceSentenceIds`

### Validation hardening

Additional L_RESPONSE validation now enforces:

- exactly 2 turns
- exactly 4 distractors
- all response texts unique
- evidence turn indexes must stay inside the 2-turn range
- final compiled payload must keep valid sentence ids and evidence ids

Additional failure codes:

- `OUTPUT_INVALID_TURN_COUNT`
- `OUTPUT_INVALID_RESPONSE_OPTIONS`
- `OUTPUT_INVALID_EVIDENCE_TURN`
- `OUTPUT_DETERMINISTIC_COMPILE_FAILED`

### Operational interpretation

The redesign is intended to make `gpt-5-mini` viable for `L_RESPONSE` without
introducing a default fallback branch.

### Live smoke outcome

The dedicated `L_RESPONSE` path was re-run with the live OpenAI provider using:

- provider: `openai`
- model: `gpt-5-mini`
- template: `content-v1-listening-response-skeleton`
- track: `M3`
- skill: `LISTENING`
- typeTag: `L_RESPONSE`
- `maxTargetsPerRun = 1`
- `maxCandidatesPerRun = 2`

Observed outcome:

- job reached `SUCCEEDED`
- at least one candidate reached `VALID`
- deterministic materialization produced a `DRAFT` revision
- reviewer batch validate/review/publish succeeded
- the published revision appeared in public list/detail/sync delivery
- M3 listening inventory improved numerically and `L_RESPONSE` stopped being a
  missing listening typeTag in the published bank

Current conclusion:

- `gpt-5-mini` is sufficient for `L_RESPONSE` when the dedicated skeleton +
  deterministic compiler path is used
- fallback remains disabled for `L_RESPONSE`
- a future fallback re-evaluation is only needed if later batches regress

## 15. B2.6.12 Controlled Inventory Backfill Round 3

This round continued real inventory fill under the frozen generation policy:

- default model: `gpt-5-mini`
- limited fallback:
  - `L_LONG_TALK -> gpt-4.1-mini`
  - `R_INSERTION -> gpt-4.1-mini`
- `L_RESPONSE`
  - dedicated `gpt-5-mini` generation mode
  - no fallback added in this round

The intent was to keep the batch small, publish successful candidates
immediately, and re-run readiness after each controlled step.

### Executed deficits

- `H1 / LISTENING / L_LONG_TALK / difficulty 2`
- `H2 / READING / R_INSERTION / difficulty 3`
- `M3 / LISTENING / L_SITUATION / difficulty 1`

### Model routing outcome

- `H1 / L_LONG_TALK`
  - model used: `gpt-4.1-mini`
  - `fallbackTriggered = true`
  - generation job id: `2611b9b4-2d52-47f5-b473-f8b3040276e1`
  - estimated cost: `0.002488`
  - publishable item per dollar: `401.92926`
- `H2 / R_INSERTION`
  - model used: `gpt-4.1-mini`
  - `fallbackTriggered = true`
  - generation job id: `01d4563a-bc2a-4636-acf7-301b0d5ad69a`
  - estimated cost: `0.001448`
  - publishable item per dollar: `690.607735`
- `M3 / L_SITUATION`
  - model used: `gpt-5-mini`
  - `fallbackTriggered = false`
  - generation job ids:
    - `fc1e807d-9071-4e8c-807a-b0891e3eb226`
    - `46b300de-df94-492f-958f-91b6b9ae9e1e`
  - both runs failed with `PROVIDER_TIMEOUT`
  - no publishable candidate was produced in this round

### Published revisions

Two round-3 candidates were materialized, validated, reviewed, and published:

- `1cc0ec1c-9acf-483a-8dd3-202b378c3e03`
  - track/skill/typeTag: `H1 / LISTENING / L_LONG_TALK`
  - source: `content_readiness_backfill`
  - generation job id: `2611b9b4-2d52-47f5-b473-f8b3040276e1`
- `3e82471e-7fc4-48b9-8510-ef2b60ecfd22`
  - track/skill/typeTag: `H2 / READING / R_INSERTION`
  - source: `content_readiness_backfill`
  - generation job id: `01d4563a-bc2a-4636-acf7-301b0d5ad69a`

Both published revisions were confirmed in public delivery:

- public detail: `200`
- public list / sync membership: confirmed

### Before / after readiness summary

- `M3`
  - Daily: `WARNING -> WARNING`
  - Weekly: `WARNING -> WARNING`
  - Monthly: `NOT_READY -> NOT_READY`
  - published counts:
    - LISTENING `11 -> 11`
    - READING `10 -> 10`
  - practical effect:
    - no improvement this round because `L_SITUATION` timed out twice

- `H1`
  - Daily: `WARNING -> WARNING`
  - Weekly: `NOT_READY -> READY`
  - Monthly: `NOT_READY -> NOT_READY`
  - published counts:
    - LISTENING `9 -> 10`
    - READING `10 -> 10`
  - practical effect:
    - `L_LONG_TALK` is no longer missing
    - listening missing tags reduced to `L_SITUATION` only

- `H2`
  - Daily: `WARNING -> WARNING`
  - Weekly: `READY -> READY`
  - Monthly: `NOT_READY -> NOT_READY`
  - published counts:
    - LISTENING `14 -> 14`
    - READING `11 -> 12`
  - practical effect:
    - `R_INSERTION` inventory deepened
    - reading-side daily / monthly deficit narrowed

- `H3`
  - unchanged

### Round 3 conclusion

- the current routing policy again produced real published inventory
- fallback materially helped on:
  - `L_LONG_TALK`
  - `R_INSERTION`
- `H1 weekly` improved from `NOT_READY` to `READY`
- `M3 L_SITUATION` remains an unresolved execution problem because of repeated
  provider timeouts, not schema invalidation

### Remaining deficits after round 3

- `M3`
  - listening missing: `L_SITUATION`
  - reading missing: `R_ORDER`, `R_SUMMARY`, `R_VOCAB`
- `H1`
  - listening missing: `L_SITUATION`
  - reading missing: `R_BLANK`, `R_ORDER`, `R_SUMMARY`
- `H2`
  - listening missing: `L_SITUATION`
  - reading missing: `R_ORDER`, `R_SUMMARY`, `R_VOCAB`

Operationally, round 3 confirmed that the remaining blocker is mostly content
depth and a small number of provider-sensitive deficits, not the general
generation pipeline.

## 16. B2.6.14 Controlled Inventory Backfill Round 4

Round 4 continued the controlled backfill loop with the same routing policy:

- default model: `gpt-5-mini`
- limited fallback:
  - `L_LONG_TALK -> gpt-4.1-mini`
  - `R_INSERTION -> gpt-4.1-mini`
- `L_RESPONSE`
  - dedicated `gpt-5-mini` generation mode
  - no fallback added in this round

Execution note:

- the local `.env` still points `R2_ENDPOINT` at a placeholder endpoint
  (`example.r2.cloudflarestorage.com`)
- for this round, generation was re-run with a local fake artifact store so the
  provider path and publish flow could complete without changing repo config
- this did not change the content payloads, review flow, or readiness math

### Executed deficits

- `M3 / LISTENING / L_RESPONSE / difficulty 2`
- `H1 / LISTENING / L_LONG_TALK / difficulty 3`
- `H2 / LISTENING / L_LONG_TALK / difficulty 3`
- `M3 / LISTENING / L_LONG_TALK / difficulty 1`

### Model routing outcome

- `M3 / L_RESPONSE`
  - attempted model policy: `gpt-5-mini` dedicated mode
  - `fallbackTriggered = false`
  - generation job ids:
    - `7bac006e-0e04-4e53-bca3-f2a8dd8764e1`
    - `f63d9bb2-1edb-4fd3-8cec-4a251cc1fae7`
  - both jobs failed with `PROVIDER_TIMEOUT`
  - no candidate was materialized or published
- `H1 / L_LONG_TALK`
  - model used: `gpt-4.1-mini`
  - `fallbackTriggered = true`
  - generation job id: `e48507e9-2e44-4ab0-b56f-872017fdf918`
  - estimated cost: `0.001448`
  - publishable item per dollar: `690.607735`
- `H2 / L_LONG_TALK`
  - model used: `gpt-4.1-mini`
  - `fallbackTriggered = true`
  - generation job id: `5de72935-6fc5-411d-a7f1-501d4a6e5f87`
  - estimated cost: `0.001448`
  - publishable item per dollar: `690.607735`
- `M3 / L_LONG_TALK`
  - model used: `gpt-4.1-mini`
  - `fallbackTriggered = true`
  - generation job id: `58b4a226-038b-47db-855c-5d48c1514918`
  - estimated cost: `0.001448`
  - publishable item per dollar: `690.607735`

### Published revisions

Three round-4 candidates were materialized, validated, reviewed, and published:

- `12abfb4c-3d0b-41b7-b364-f7445e03ba8f`
  - track/skill/typeTag: `H1 / LISTENING / L_LONG_TALK`
  - source: `content_readiness_backfill`
  - generation job id: `e48507e9-2e44-4ab0-b56f-872017fdf918`
- `5bd879d1-70b7-4b1b-8ba4-df394ce68ae5`
  - track/skill/typeTag: `H2 / LISTENING / L_LONG_TALK`
  - source: `content_readiness_backfill`
  - generation job id: `5de72935-6fc5-411d-a7f1-501d4a6e5f87`
- `086d9329-7115-4fb7-808c-7d060aaabf12`
  - track/skill/typeTag: `M3 / LISTENING / L_LONG_TALK`
  - source: `content_readiness_backfill`
  - generation job id: `58b4a226-038b-47db-855c-5d48c1514918`

All three published revisions were confirmed in public delivery:

- public detail: `200`
- public list membership: confirmed
- public sync upsert membership: confirmed

### Before / after readiness summary

- `M3`
  - Daily: `WARNING -> WARNING`
  - Weekly: `WARNING -> WARNING`
  - Monthly: `NOT_READY -> NOT_READY`
  - published counts:
    - LISTENING `11 -> 12`
    - READING `10 -> 10`
  - practical effect:
    - listening inventory increased
    - `L_SITUATION` remains the only missing listening typeTag
    - `L_RESPONSE` still needs a stable live execution path

- `H1`
  - Daily: `WARNING -> WARNING`
  - Weekly: `READY -> READY`
  - Monthly: `NOT_READY -> NOT_READY`
  - published counts:
    - LISTENING `10 -> 11`
    - READING `10 -> 10`
  - practical effect:
    - listening depth increased through fallback-routed `L_LONG_TALK`
    - `L_SITUATION` remains the only missing listening typeTag

- `H2`
  - Daily: `WARNING -> WARNING`
  - Weekly: `READY -> READY`
  - Monthly: `NOT_READY -> NOT_READY`
  - published counts:
    - LISTENING `14 -> 15`
    - READING `12 -> 12`
  - practical effect:
    - listening depth increased through fallback-routed `L_LONG_TALK`
    - `L_SITUATION` remains the only missing listening typeTag

- `H3`
  - unchanged

### Round 4 conclusion

- round 4 again confirmed that the current routing policy produces real published
  inventory
- fallback materially helped on `L_LONG_TALK` across `M3`, `H1`, and `H2`
- the main unresolved provider-sensitive deficit is now `L_SITUATION`
- `M3 / L_RESPONSE` did not fail on schema in this round; it failed on repeated
  provider timeout before candidate materialization

### Remaining deficits after round 4

- `M3`
  - listening missing: `L_SITUATION`
  - reading missing: `R_ORDER`, `R_SUMMARY`, `R_VOCAB`
- `H1`
  - listening missing: `L_SITUATION`
  - reading missing: `R_BLANK`, `R_ORDER`, `R_SUMMARY`
- `H2`
  - listening missing: `L_SITUATION`
  - reading missing: `R_ORDER`, `R_SUMMARY`, `R_VOCAB`

Operationally, round 4 improved published listening depth on all three
non-ready tracks while keeping the routing policy unchanged. The remaining
blocker is concentrated in a smaller set of provider-sensitive deficits rather
than the general backfill pipeline.

## 17. B2.6.15 Controlled Inventory Backfill Round 5

Round 5 targeted the remaining `M3/H1/H2` Daily and Mock deficits from the
latest readiness report, with no model-policy change:

- default model: `gpt-5-mini`
- limited fallback:
  - `L_LONG_TALK -> gpt-4.1-mini`
  - `R_INSERTION -> gpt-4.1-mini`
- `L_RESPONSE`
  - dedicated `gpt-5-mini` generation mode
  - no fallback added
- `L_SITUATION`
  - kept on `gpt-5-mini`
  - no new fallback opened in this round

Execution note:

- the first round-5 attempts used the existing runtime default
  `AI_PROVIDER_HTTP_TIMEOUT_SECONDS=20`
- `L_SITUATION`, `R_BLANK`, `R_ORDER`, and `R_VOCAB` all hit repeat
  `PROVIDER_TIMEOUT` at roughly the same 20 second boundary
- after verifying that artifact storage was healthy again, API and worker were
  restarted with `AI_PROVIDER_HTTP_TIMEOUT_SECONDS=60`
- with the longer runtime timeout, two previously timed-out `gpt-5-mini` jobs
  completed successfully and were published

### Initial round-5 deficit attempts

- `M3 / LISTENING / L_SITUATION / difficulty 1`
  - generation job id: `fd2a3e73-be0a-41d0-ae18-5d459b6b548d`
  - model used: `gpt-5-mini`
  - `fallbackTriggered = false`
  - result: `DEAD_LETTER / PROVIDER_TIMEOUT`
- `H1 / READING / R_BLANK / difficulty 2`
  - generation job id: `bcbbf23b-54a4-4b0c-a60a-bfe8113e0d27`
  - model used: `gpt-5-mini`
  - `fallbackTriggered = false`
  - result: `DEAD_LETTER / PROVIDER_TIMEOUT`
- `H2 / READING / R_ORDER / difficulty 3`
  - generation job id: `05b18ad7-84b3-4d7e-9f7b-80ced62ac43f`
  - model used: `gpt-5-mini`
  - `fallbackTriggered = false`
  - result: `FAILED / PROVIDER_TIMEOUT`

These three attempts did not produce publishable inventory and are recorded as
provider-timeout failures rather than model-routing failures.

### Successful round-5 publish path

After the timeout increase, two small `gpt-5-mini` batches succeeded and were
materialized, validated, reviewed, and published:

- `M3 / LISTENING / L_DETAIL / difficulty 1`
  - generation job id: `31120976-9c6c-4a98-870f-a10f5c0bf74e`
  - model used: `gpt-5-mini`
  - `fallbackTriggered = false`
  - candidate id: `09e99dfd-e0a1-46e5-88d8-c73ef374a665`
  - published revision id: `b9ed178e-ce0f-4825-87a6-95caf1e82e14`
  - published unit id: `8f84866f-87da-433d-a5d7-b976d1931477`
  - estimated cost: `0.001555`
  - publishable item per dollar: `643.086817`
- `M3 / READING / R_VOCAB / difficulty 1`
  - generation job id: `9ea2cdcd-c09c-49e3-8362-b46303662546`
  - model used: `gpt-5-mini`
  - `fallbackTriggered = false`
  - candidate id: `a38d8721-9e29-40fc-8d90-cc1b62b12309`
  - published revision id: `06837956-1660-4375-893d-132ca611cbb3`
  - published unit id: `f396bb3f-4fc1-45d6-a50c-431b4c2357f5`
  - estimated cost: `0.001555`
  - publishable item per dollar: `643.086817`

Both revisions were confirmed in public delivery:

- public list membership: confirmed
- public sync upsert membership: confirmed
- public detail contract: confirmed

### Before / after readiness summary

- `M3`
  - Daily: `WARNING -> WARNING`
  - Weekly: `WARNING -> WARNING`
  - Monthly: `NOT_READY -> NOT_READY`
  - published counts:
    - LISTENING `12 -> 13`
    - READING `10 -> 11`
  - practical effect:
    - `R_VOCAB` is no longer missing
    - missing reading typeTags reduced from `R_ORDER, R_SUMMARY, R_VOCAB`
      to `R_ORDER, R_SUMMARY`
    - listening depth increased again even though `L_SITUATION` remains open

- `H1`
  - Daily: `WARNING -> WARNING`
  - Weekly: `READY -> READY`
  - Monthly: `NOT_READY -> NOT_READY`
  - published counts:
    - LISTENING `11 -> 11`
    - READING `10 -> 10`
  - practical effect:
    - no net publish increase in this round
    - `R_BLANK` remains blocked by provider timeout

- `H2`
  - Daily: `WARNING -> WARNING`
  - Weekly: `READY -> READY`
  - Monthly: `NOT_READY -> NOT_READY`
  - published counts:
    - LISTENING `15 -> 15`
    - READING `12 -> 12`
  - practical effect:
    - no net publish increase in this round
    - `R_ORDER` remains blocked by provider timeout

- `H3`
  - unchanged

### Round 5 conclusion

- round 5 produced real inventory growth again, even though the initially
  chosen hard deficits timed out under the 20 second runtime limit
- the actual blocker was the provider timeout setting, not a new model-policy
  defect
- with `AI_PROVIDER_HTTP_TIMEOUT_SECONDS=60`, `gpt-5-mini` succeeded on two
  non-fallback Daily count deficits and produced two additional published
  revisions
- `M3` Daily reading inventory improved enough to remove `R_VOCAB` from the
  missing-type list

### Remaining deficits after round 5

- `M3`
  - listening missing: `L_SITUATION`
  - reading missing: `R_ORDER`, `R_SUMMARY`
- `H1`
  - listening missing: `L_SITUATION`
  - reading missing: `R_BLANK`, `R_ORDER`, `R_SUMMARY`
- `H2`
  - listening missing: `L_SITUATION`
  - reading missing: `R_ORDER`, `R_SUMMARY`, `R_VOCAB`

Operationally, round 5 showed that the content-generation routing policy is
still sound, but some remaining deficits are now constrained by provider
latency more than by schema validity. The next controlled backfill round should
either keep the higher runtime timeout or explicitly record timeout-sensitive
targets as a separate execution class.

## 18. B2.6.17 Calibrated Inventory Backfill

`B2.6.17` was the first controlled backfill round executed after the track
calibration gate became a publish requirement.

The operating rule for this round was stricter than earlier inventory rounds:

- `H2/H3` items that failed calibration were not published under any
  circumstance.
- `M3/H1` warning-mode tracks were also treated conservatively; warning-only
  items were not added unless they clearly improved calibrated inventory.
- success was defined as adding at least one calibration-pass revision rather
  than simply increasing raw schema-valid inventory.

### Runtime and execution note

- the local API and worker were healthy, but Celery dispatch left several AI
  generation jobs stuck in `QUEUED`
- to finish the calibrated backfill without changing application code, the
  queued jobs were executed through the same backend service path used by the
  worker
- the run again required `AI_PROVIDER_HTTP_TIMEOUT_SECONDS=60`; the default
  20-second boundary continued to produce avoidable provider timeouts

### Attempted calibrated batches

- `H2 / READING / R_ORDER / difficulty 3`
  - generation job id: `37f039d4-46ea-49ac-9645-56999c4bfc3c`
  - model used: `gpt-5-mini`
  - `fallbackTriggered = false`
  - generation status after retry: `SUCCEEDED`
  - materialized revisions:
    - `b49b5dcd-5d74-4662-a60e-e4976d145536`
    - `330428da-27a6-4648-80ac-9b505cd96ddc`
    - `c0113069-bef9-46c8-b371-74e3b7d7d532`
  - calibration outcome:
    - scores `42-45`
    - calibrated level `STANDARD`
    - pass `false`
    - repeated fail reasons:
      - `inference_load_below_track_baseline`
      - `reading_discourse_inference_too_low`
      - `structure_complexity_below_track_baseline`
      - `track_level_mismatch:H2:STANDARD`
  - publish result: hard-blocked by calibration, `0` published

- `M3 / READING / R_ORDER / difficulty 2`
  - generation job id: `0d3c5f94-a09c-4e54-aad4-beca4336cba4`
  - model used: `gpt-5-mini`
  - `fallbackTriggered = false`
  - generation status: `SUCCEEDED`
  - materialized revisions:
    - `a2be3b7a-3ab2-4c04-bf54-47c4b8ef786f`
    - `0ac70fa8-29cc-4735-96b9-f2f5ae295780`
  - calibration outcome:
    - scores `42-49`
    - calibrated level `STANDARD`
    - pass `false`
    - main fail reason: `inference_load_below_track_baseline`
  - publish result:
    - warning-mode track, but intentionally not published
    - this round treated warning-only inventory as non-goal inventory

- `H2 / LISTENING / L_SITUATION / difficulty 3`
  - generation job id: `d8e8b540-89c3-44a1-8335-d3bdcf640c75`
  - model used: `gpt-5-mini`
  - `fallbackTriggered = false`
  - generation status: `SUCCEEDED`
  - calibration outcome:
    - scores `62-65`
    - calibrated level `HARD`
    - pass `false`
    - fail reasons:
      - `inference_load_below_track_baseline`
      - `listening_situation_context_inference_too_low`
  - publish result: hard-blocked by calibration, `0` published

- `H1 / LISTENING / L_SITUATION / difficulty 2`
  - generation job id: `c583911d-e800-426b-b813-79b440475c5f`
  - model used: `gpt-5-mini`
  - `fallbackTriggered = false`
  - generation status: `SUCCEEDED`
  - calibration outcome:
    - scores `58-59`
    - calibrated level `HARD`
    - pass `false`
    - fail reasons:
      - `inference_load_below_track_baseline`
      - `listening_situation_context_inference_too_low`
  - publish result:
    - warning-mode track, but intentionally not published
    - this remains a calibration/inference gap rather than a schema gap

- `H1 / READING / R_BLANK / difficulty 3`
  - generation job id: `d100fb1c-0c5e-42aa-8b59-7f0c414d80ef`
  - model used: `gpt-5-mini`
  - `fallbackTriggered = false`
  - result: `FAILED / PROVIDER_TIMEOUT`

- `H2 / LISTENING / L_LONG_TALK / difficulty 3`
  - generation job id: `9d764f57-1d67-4df1-a3ad-2e1e1c664ed9`
  - model used: `gpt-4.1-mini`
  - `fallbackTriggered = true`
  - estimated cost: `0.001448`
  - generation status: `SUCCEEDED`
  - materialized revision:
    - `890a6038-4adf-45ab-8939-f4b812fc13ec`
  - calibration outcome:
    - score `83`
    - calibrated level `KILLER`
    - pass `false`
    - fail reasons:
      - `inference_load_below_track_baseline`
      - `listening_long_talk_inference_too_low`
  - publish result: hard-blocked by calibration, `0` published

- `H1 / LISTENING / L_LONG_TALK / difficulty 2`
  - generation job id: `46329d4f-fbb7-418c-ab89-a7471427332b`
  - model used: `gpt-4.1-mini`
  - `fallbackTriggered = true`
  - candidate result:
    - `OUTPUT_SENTENCE_ID_MISMATCH`
    - `listening_turn_sentence_alignment_invalid`
  - publish result: `0` published

### Successful calibrated publish

Only one batch produced a clean calibration-pass revision, and that revision
was published:

- `H1 / READING / R_SUMMARY / difficulty 3`
  - generation job id: `bdd68d89-6e7b-4f22-941f-6010d0dfbcb1`
  - model used: `gpt-5-mini`
  - `fallbackTriggered = false`
  - estimated cost: `0.001555`
  - candidate id: `63642b7d-ac24-4d3a-890f-2645abe03a8c`
  - published revision id: `50acb965-0c3a-4bb5-98a6-5419b85477c4`
  - published unit id: `e0dfd5d4-51ac-495d-9669-8c0aa47004a3`
  - calibration score: `61`
  - calibrated level: `HARD`
  - pass: `true`
  - warnings: `[]`
  - fail reasons: `[]`
  - rubric version: `2026-03-13-b2.6.16`
  - publishable item per dollar: `643.086817`

The published revision was confirmed in public delivery:

- public list membership: confirmed
- public sync upsert membership: confirmed
- public detail contract: confirmed

### Before / after readiness summary

- `M3`
  - Daily: `WARNING -> WARNING`
  - Weekly: `WARNING -> WARNING`
  - Monthly: `NOT_READY -> NOT_READY`
  - published counts:
    - LISTENING `13 -> 13`
    - READING `11 -> 11`
  - practical effect:
    - no calibrated publish increase in this round
    - `L_SITUATION`, `R_ORDER`, and `R_SUMMARY` still require a stronger
      inference load

- `H1`
  - Daily: `WARNING -> WARNING`
  - Weekly: `READY -> READY`
  - Monthly: `NOT_READY -> NOT_READY`
  - published counts:
    - LISTENING `11 -> 11`
    - READING `10 -> 11`
  - practical effect:
    - `R_SUMMARY` is no longer missing
    - reading missing typeTags reduced from
      `R_BLANK, R_ORDER, R_SUMMARY` to `R_BLANK, R_ORDER`
    - this round added the first explicitly calibration-pass inventory growth

- `H2`
  - Daily: `WARNING -> WARNING`
  - Weekly: `READY -> READY`
  - Monthly: `NOT_READY -> NOT_READY`
  - published counts:
    - LISTENING `15 -> 15`
    - READING `12 -> 12`
  - practical effect:
    - calibration hard-block worked as intended
    - no low-calibration `R_ORDER`, `L_SITUATION`, or `L_LONG_TALK` item was
      allowed through

- `H3`
  - unchanged

### Round 17 conclusion

- `B2.6.17` proved that calibration is now the real publish gate, not schema
  validity alone
- `H2/H3` hard-blocking worked in live execution
- `M3/H1` warning-mode inventory was kept out on purpose when it did not meet
  the calibrated quality bar
- only one item was published in this round, but it was a genuinely
  calibration-pass item and it reduced a real `H1` deficit
- future backfill rounds should be judged primarily by calibration-pass yield
  rather than raw generation or raw validation volume

### Remaining deficits after B2.6.17

- `M3`
  - listening missing: `L_SITUATION`
  - reading missing: `R_ORDER`, `R_SUMMARY`
- `H1`
  - listening missing: `L_SITUATION`
  - reading missing: `R_BLANK`, `R_ORDER`
- `H2`
  - listening missing: `L_SITUATION`
  - reading missing: `R_ORDER`, `R_SUMMARY`, `R_VOCAB`

## 19. B2.6.19 Calibrated Inventory Backfill

`B2.6.19` was executed under the phase-2 quality policy frozen in `B2.6.18`.
This round counted inventory growth only when a revision reached:

- schema valid
- calibration pass
- quality gate pass
- published state

Warning-only drafts were not counted as inventory growth, even on `M3/H1`.

### Runtime note

- the local queue still showed intermittent dispatch lag, so the live batches
  were executed through the same worker service path used by the queue worker
- the default `AI_PROVIDER_HTTP_TIMEOUT_SECONDS=20` again distorted several
  runs into `PROVIDER_TIMEOUT`
- for the reading retries, the runtime timeout was raised to `60` seconds so
  the result reflected content quality rather than transport noise
- `H1/H2 L_SITUATION` also showed that first-attempt timeout output was not
  always the final truth; those jobs later completed on retry and had to be
  materialized/reviewed explicitly

### Executed batches

- `M3 / LISTENING / L_SITUATION / difficulty 1`
  - generation job id: `9327a99a-5a14-48b3-9a46-63fd5bace440`
  - model used: `gpt-5-mini`
  - `fallbackTriggered = false`
  - generation status: `SUCCEEDED`
  - published revisions:
    - `8c6744fa-a497-41b9-a017-4e80cb3c0c8d`
      - calibration score: `45`
      - calibrated level: `STANDARD`
      - pass: `true`
      - warnings: `[]`
    - `c73636e3-9578-4915-8c12-7dec072574d8`
      - calibration score: `41`
      - calibrated level: `STANDARD`
      - pass: `true`
      - warnings: `[]`
  - publish result:
    - `2` published
    - publishable item per dollar: `700.525394`

- `H1 / LISTENING / L_SITUATION / difficulty 2`
  - generation job id: `3f4ebdb1-b7ac-4d6a-96a8-bbc8176894eb`
  - model used: `gpt-5-mini`
  - `fallbackTriggered = false`
  - generation status after retry: `SUCCEEDED`
  - published revision:
    - `6fdb5ca4-b6a4-43ce-89d6-026516a8ee4f`
      - calibration score: `52`
      - calibrated level: `STANDARD`
      - pass: `true`
      - warnings: `[]`
  - blocked companion draft:
    - `70e2c65a-a9a4-495e-bb82-cf000100317c`
      - calibrated level: `STANDARD`
      - pass: `false`
      - fail reasons:
        - `inference_load_below_track_baseline`
        - `listening_situation_context_inference_too_low`
  - publish result:
    - `1` published
    - publishable item per dollar: `350.262697`

- `H2 / LISTENING / L_SITUATION / difficulty 3`
  - generation job id: `fff96cc2-3617-4b0f-9e43-d28f0ae9628d`
  - model used: `gpt-5-mini`
  - `fallbackTriggered = false`
  - generation status after retry: `SUCCEEDED`
  - materialized drafts:
    - `a70b1001-6863-4d67-a99c-22e4ccb97799`
      - calibration score: `50`
      - calibrated level: `STANDARD`
      - pass: `false`
    - `df9fe64f-fa21-49aa-ad59-e66482c780dc`
      - calibration score: `42`
      - calibrated level: `STANDARD`
      - pass: `false`
  - repeated fail reasons:
    - `inference_load_below_track_baseline`
    - `listening_situation_context_inference_too_low`
  - publish result:
    - fail-close block
    - `0` published

- `H1 / READING / R_BLANK / difficulty 2`
  - generation job id: `ec2c3431-f7b8-4d73-b0b4-6a259073e205`
  - model used: `gpt-5-mini`
  - `fallbackTriggered = false`
  - runtime override: `AI_PROVIDER_HTTP_TIMEOUT_SECONDS=60`
  - generation status: `SUCCEEDED`
  - materialized drafts:
    - `f175d86c-24ca-4028-aee2-07f155f13525`
      - calibration score: not high enough for publish
      - calibrated level: `STANDARD`
      - pass: `false`
      - fail reasons:
        - `inference_load_below_track_baseline`
    - `f139380d-5a18-401b-ac40-5d7dcb035c20`
      - calibrated level: `EASY`
      - pass: `false`
      - fail reasons:
        - `structure_complexity_below_track_baseline`
        - `track_level_mismatch:H1:EASY`
  - publish result:
    - `0` published

- `H1 / READING / R_ORDER / difficulty 2`
  - generation job id: `4970db59-16ef-4b0e-a35f-bba328feeb07`
  - model used: `gpt-5-mini`
  - `fallbackTriggered = false`
  - runtime override: `AI_PROVIDER_HTTP_TIMEOUT_SECONDS=60`
  - generation status: `SUCCEEDED`
  - materialized drafts:
    - `ae3f4e95-da7b-4e42-84fb-4c17c171eb35`
      - calibration score: `33`
      - calibrated level: `EASY`
      - pass: `false`
    - `ced58ea7-a33b-4609-8eb2-e66b66d67e50`
      - calibration score: `37`
      - calibrated level: `EASY`
      - pass: `false`
  - repeated fail reasons:
    - `inference_load_below_track_baseline`
    - `track_level_mismatch:H1:EASY`
    - `length_too_short`
  - publish result:
    - `0` published

### Public delivery confirmation

The newly published calibrated revisions were verified in public delivery:

- `M3 / L_SITUATION`
  - public detail confirmed for `8c6744fa-a497-41b9-a017-4e80cb3c0c8d`
  - public sync membership confirmed
- `H1 / L_SITUATION`
  - public list membership confirmed
  - public sync membership confirmed
  - public detail confirmed for `6fdb5ca4-b6a4-43ce-89d6-026516a8ee4f`

### Before / after readiness summary

- `M3`
  - Daily: `WARNING -> WARNING`
  - Weekly: `WARNING -> WARNING`
  - Monthly: `NOT_READY -> NOT_READY`
  - published counts:
    - LISTENING `13 -> 15`
    - READING `11 -> 11`
  - practical effect:
    - `L_SITUATION` is no longer missing
    - listening missing typeTags reduced from `L_SITUATION` to none
    - Daily still remains `WARNING` because the track is still short on depth
      and reading-side calibrated inventory

- `H1`
  - Daily: `WARNING -> WARNING`
  - Weekly: `READY -> READY`
  - Monthly: `NOT_READY -> NOT_READY`
  - published counts:
    - LISTENING `11 -> 12`
    - READING `11 -> 11`
  - practical effect:
    - `L_SITUATION` is no longer missing
    - reading deficits remain `R_BLANK`, `R_ORDER`
    - the round added one more calibration-pass inventory item without relying
      on fallback

- `H2`
  - Daily: `WARNING -> WARNING`
  - Weekly: `READY -> READY`
  - Monthly: `NOT_READY -> NOT_READY`
  - published counts:
    - LISTENING `15 -> 15`
    - READING `12 -> 12`
  - practical effect:
    - `L_SITUATION` is still missing
    - hard-block policy worked as intended
    - low-inference situation items were not allowed through

- `H3`
  - unchanged

### Round 19 conclusion

- `B2.6.19` produced real calibration-pass inventory growth again
- the quality gate is now doing the right thing in both directions:
  - `M3/H1` can still add good inventory when it genuinely clears the gate
  - `H2` fail-close blocks weak situation items even when they are schema-valid
- the main blocker for the remaining deficits is now clearer:
  - `L_SITUATION` needs stronger context inference at `H2`
  - `R_BLANK` and `R_ORDER` still skew too easy/too short for `H1`
- future backfill rounds should keep separating:
  - transport noise (`PROVIDER_TIMEOUT`)
  - true quality-gate failures

### Remaining deficits after B2.6.19

- `M3`
  - listening missing: none
  - reading missing: `R_ORDER`, `R_SUMMARY`
- `H1`
  - listening missing: none
  - reading missing: `R_BLANK`, `R_ORDER`
- `H2`
  - listening missing: `L_SITUATION`
  - reading missing: `R_ORDER`, `R_SUMMARY`, `R_VOCAB`
