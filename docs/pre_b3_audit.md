# PRE-B3 Audit And Policy Freeze

Last updated: 2026-03-10

## Scope

This document freezes the pre-B3 audit baseline for:

- Daily content coverage
- Vocabulary bank suitability
- Weekly/monthly mock assembly suitability
- Daily order policy
- Adaptive selection design notes

It is intentionally an audit and policy document. It does not change user-facing
product behavior by itself.

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
  - backend vocab catalog may still be absent if the local policy remains aligned

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

### Current committed vocabulary source

The committed local source currently has:

- 3 vocabulary items total in `starter_pack.json`

`vocab_master` supports only:

- `id`
- `lemma`
- `pos`
- `meaning`
- `example`
- `ipa`
- `deleted_at`
- `created_at`

It does **not** currently store:

- track band
- target exam level
- CSAT/Suneung source tag
- frequency tier
- difficulty band
- curriculum year/series

### Can the current structure support track-differentiated vocab selection?

Not reliably.

The current repository can support:

- SRS state
- bookmarking
- deterministic daily quiz ordering

It cannot yet support academically meaningful M3/H1/H2/H3 progression because
the core metadata required to separate vocab by school level or exam target is
missing.

### Proposed selection rule to freeze now

The long-term progression target is CSAT-oriented vocabulary.

Frozen rule for future implementation:

- M3: prioritize high-frequency foundational academic vocabulary
- H1: prioritize lower-band CSAT/core school vocabulary
- H2: prioritize mid-band CSAT vocabulary plus carry-over review
- H3: prioritize upper-band CSAT vocabulary plus spaced review of prior bands

### Additional metadata required

At minimum, vocabulary items need:

- `sourceTag` (`CSAT`, `school_core`, `custom`, etc.)
- `targetMinTrack`
- `targetMaxTrack`
- `difficultyBand`
- optional `frequencyTier`

Without these fields, track-specific vocab selection remains heuristic at best.

### Vocabulary readiness verdict

- Current local quiz/demo flow: `Serviceable for development only`
- Real grade-differentiated service: `Not sufficient`

Status: `NOT_READY`

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

Implementation is intentionally deferred.

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

- Daily order preference can be implemented after policy freeze
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
  - `content-v1-listening-response`
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
- `L_RESPONSE` remains excluded pending a separate generation redesign
