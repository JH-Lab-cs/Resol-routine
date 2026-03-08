# Adaptive Selection Design

Last updated: 2026-03-08

## Purpose

This document freezes the post-B3 design direction for a user-specific adaptive
selection layer.

It does **not** authorize implementation in the current phase.

Current status:

- Daily ordering policy is implemented
- Content delivery and sync contracts are implemented
- User-specific adaptive selection is intentionally deferred until after B3

Implementation gate:

- Do not implement this before event sync and cache invalidation behavior are
  proven stable in integrated frontend/backend flows.

## Non-Goals

This document does not define:

- backend API changes for the current milestone
- final production weights tuned by live telemetry
- adaptive logic for weekly/monthly mock flows
- SRS vocab scheduling rules

Weekly/monthly mock sets keep deterministic assembly and fixed ordering.

## Scope Of The Future Adaptive Layer

The future adaptive layer is intended for user-specific Daily item selection
only.

Candidate pool assumptions:

- content is already content-policy compliant
- content uses canonical semantic `typeTag`
- track / skill / difficulty metadata is valid
- item identity is stable at least at the `revisionId` level

Selection objective:

- improve repetition quality
- prioritize learning value over raw novelty
- preserve track-appropriate and exam-appropriate difficulty
- avoid over-serving recently seen content

## Frozen Scoring Inputs

The score must reflect at least the following components:

- unseen bonus
- wrong bonus
- stale bonus
- recency penalty
- difficulty fit
- track fit
- target exam level fit

The system may add more terms later, but these are the minimum required
components for the first adaptive implementation.

## Required Data Contract

Adaptive selection depends on synced per-user learning history. The minimum data
contract is:

- `revisionId`
- stable content identity for grouping/replacement logic
  - preferred: `unitId` + `revisionId`
- `track`
- `skill`
- canonical `typeTag`
- `difficulty`
- `attemptedAtUtc`
- `isCorrect`
- `wrongReasonTag`
- `lastSeenAtUtc`
- `exposureCount`
- `successStreak`
- familiarity state or an equivalent derived score

Recommended optional inputs:

- response time
- elapsed review interval
- session source (`daily`, `mock_weekly`, `mock_monthly`)
- client locale or learning preference flags

## Derived Features

The adaptive layer should derive, not store blindly, the following values when
possible:

- `daysSinceLastSeen`
- `recentWrongCount`
- `recentExposureCount`
- `familiarityScore`
- `targetDifficultyDistance`
- `targetExamLevelDistance`

Recommended derivation rules:

- `lastSeenAtUtc` = latest synced attempt timestamp for the item
- `exposureCount` = total synced attempts for the item
- `successStreak` = consecutive correct attempts up to the latest attempt
- `familiarityScore` = normalized score built from exposure count, success
  streak, and recency

## Candidate Eligibility Rules

Before scoring, items should be filtered by hard eligibility rules.

Minimum hard filters:

- same track, unless an explicit cross-track fallback policy is introduced
- skill bucket required by the Daily slot
- canonical taxonomy only
- public/published content only
- not tombstoned for the client

Recommended early exclusion rules:

- item seen too recently in the same Daily flow
- item exceeds repetition cap for the active rolling window
- item belongs to an intentionally blocked remediation bucket

## Draft Scoring Formula

The initial scoring formula should remain simple and auditable.

Recommended first-pass formula:

```text
score =
  unseen_bonus
  + wrong_bonus
  + stale_bonus
  - recency_penalty
  + difficulty_fit
  + track_fit
  + target_exam_level_fit
```

This should be implemented as a deterministic numeric score.

## Recommended Term Definitions

### 1. Unseen Bonus

Definition:

- reward items with `exposureCount == 0`

Suggested rule:

```text
unseen_bonus = 100 if exposureCount == 0 else 0
```

Reason:

- the system should strongly prefer unseen content until the user history
  becomes deep enough to support richer remediation

### 2. Wrong Bonus

Definition:

- reward items the user previously answered incorrectly

Suggested rule:

```text
wrong_bonus = 60 * recent_wrong_weight
```

Suggested `recent_wrong_weight` examples:

- `1.0` for a recent wrong item
- `0.5` for an older wrong item
- `0.0` for items with no wrong history

Reason:

- wrong answers are a strong signal for remediation priority

### 3. Stale Bonus

Definition:

- reward items that have not been seen for a long enough interval

Suggested rule:

```text
stale_bonus = min(daysSinceLastSeen, 30) * 1.5
```

Reason:

- this gives steady preference to review items without allowing ancient history
  to dominate forever

### 4. Recency Penalty

Definition:

- penalize items seen too recently

Suggested rule:

```text
recency_penalty = 40 if lastSeenAtUtc is within the recent-repeat window else 0
```

Recommended initial recent-repeat window:

- same day for Daily
- optionally tighter within the same unfinished Daily session

Reason:

- prevents low-value repetition caused by deterministic candidate pools

### 5. Difficulty Fit

Definition:

- reward items whose difficulty is close to the current target level

Suggested rule:

```text
difficulty_fit = max(0, 20 - (difficulty_distance * 8))
```

Where:

- `difficulty_distance = abs(itemDifficulty - targetDifficulty)`

Reason:

- keeps Daily close to the intended challenge band while still allowing some
  variance

### 6. Track Fit

Definition:

- reward items aligned to the user's track

Suggested rule:

```text
track_fit = 15 for exact track match, else 0
```

Reason:

- the first adaptive version should stay conservative and avoid cross-track
  blending

### 7. Target Exam Level Fit

Definition:

- reward items whose exam orientation matches the user's current preparation
  target

Suggested rule:

```text
target_exam_level_fit = 0..15
```

Possible interpretation:

- exact exam-target match: `+15`
- adjacent band: `+8`
- otherwise: `0`

Reason:

- separates difficulty from exam style or curriculum target

## Example Weight Profile

The first implementation should use explicitly documented weights and avoid
model-generated weights.

Suggested starting profile:

- unseen bonus: `+100`
- wrong bonus: up to `+60`
- stale bonus: up to `+45`
- recency penalty: `-40`
- difficulty fit: `0..+20`
- track fit: `0..+15`
- target exam level fit: `0..+15`

Interpretation:

- novelty and remediation dominate
- recent-repeat avoidance is strong
- metadata fit acts as a constraint-aware tie-breaker

## Familiarity And Success Streak Policy

The adaptive layer should not treat all seen items equally.

Recommended familiarity interpretation:

- low familiarity:
  - exposure count is low
  - success streak is low
  - wrong history is recent
- high familiarity:
  - exposure count is high
  - success streak is stable
  - item was answered correctly repeatedly

Suggested usage:

- low familiarity should preserve eligibility
- high familiarity should reduce score unless the item is stale enough to come
  back into rotation

This keeps Daily from overserving already-mastered content.

## Wrong Reason Tag Usage

`wrongReasonTag` should influence remediation priority.

Recommended future policy:

- `VOCAB`
  - favor same-skill items with manageable difficulty and lexical support
- `EVIDENCE`
  - favor questions with clearer sentence grounding
- `INFERENCE`
  - favor adjacent-difficulty reasoning practice
- `CARELESS`
  - lower than conceptual-error priority, but still eligible
- `TIME`
  - favor shorter or less dense items within the same target band

This should remain heuristic in the first version.
Do not overfit early logic to wrong-reason tags before real synced data exists.

## Daily Slot Strategy

Adaptive selection should still honor Daily slot structure.

Current product rule:

- Daily consists of 3 listening + 3 reading items

Recommended adaptive strategy:

- score listening candidates against listening slots
- score reading candidates against reading slots
- select top valid items per skill bucket

This preserves Daily structure while allowing user-specific ranking inside each
skill.

## Determinism And Tie-Breaking

Adaptive selection does not mean nondeterministic selection.

Recommended rule:

- score candidates deterministically from persisted history and metadata
- tie-break by stable item identity
  - preferred: `revisionId`
  - fallback: `unitId`, then `revisionId`

Reason:

- makes debugging, report analysis, and regression testing tractable

## Interaction With Sync And Cache Invalidation

Adaptive selection must rely on the published-content sync layer introduced
before B3.

Requirements:

- tombstoned or deleted items must be removed from eligibility
- stale signed URLs must not affect payload cache decisions
- selection should operate on content metadata and user history, not on cached
  media URLs

Client cache key policy remains:

- payload cache key: `revisionId`
- signed URL: short-lived and non-cache-authoritative

## Why Implementation Is Deferred Until After B3

Adaptive selection must wait until after B3 because it depends on stable:

- frontend/backend sync behavior
- attempt-history semantics
- content invalidation behavior
- published-content identity handling

If implemented before B3:

- unseen/wrong/stale signals may be incomplete
- local/offline history may diverge from synced history
- deleted or replaced content may still be selected incorrectly

Frozen implementation timing:

- earliest acceptable phase: after B3 sync/event behavior is stable

## Open Questions For Post-B3

These are intentionally left open for later calibration:

- whether cross-track fallback should ever be allowed
- whether same-day recency should be strict exclusion or only a penalty
- how strongly `wrongReasonTag` should alter selection
- whether response time should influence familiarity
- whether the target exam level should be user-configured or inferred

These are tuning questions, not blockers for the first implementation.

## Summary

The first adaptive Daily selector should:

- use deterministic scoring
- prioritize unseen, wrong, and stale items
- penalize recent repeats
- preserve track and target-difficulty fit
- depend on synced per-user history
- wait until after B3 for implementation

This document freezes the required scoring components and minimum data contract
for that future work.
