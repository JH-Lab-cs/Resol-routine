# PRE-B3 Audit And Policy Freeze

Last updated: 2026-03-08

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
