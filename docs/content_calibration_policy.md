# Content Calibration Policy

## Scope

This document freezes the publish-time calibration policy for backend-authored
content.

The core rule is:

- `schema valid != publishable`
- `publishable = schema valid + calibration pass + quality gate pass`

## Track Baseline

- `M3`: `EASY ~ STANDARD` 중심, 일부 `HARD`
- `H1`: `STANDARD` 중심, 일부 `HARD`
- `H2`: `HARD` 중심
- `H3`: `HARD ~ KILLER` 중심

Question calibration levels are fixed as:

- `TOO_EASY`
- `EASY`
- `STANDARD`
- `HARD`
- `KILLER`
- `TOO_HARD`

## Publish Gate

- `H2/H3`
  - hard typeTags are fail-close
  - shadow-evaluated typeTags still store the full quality trace
- `M3/H1`
  - warning mode is limited by a warning budget
  - warning budget `<= 1`: reviewer publish allowed
  - warning budget `>= 2`: `overrideRequired = true`
  - `length_too_short` and `direct_clue_too_strong` are immediate block reasons

Rubric / quality gate versions:

- `calibrationRubricVersion = 2026-03-15-b2.6.18`
- `qualityGateVersion = 2026-03-15-b2.6.18`

## Calibration Metrics

Every evaluation stores:

- `calibrationScore`
- `calibratedLevel`
- `calibrationPass`
- `calibrationWarnings`
- `calibrationFailReasons`
- `calibrationRubricVersion`

Underlying metric dimensions:

- `lexicalDifficultyScore`
- `discourseComplexityScore`
- `distractorStrengthScore`
- `clueDirectnessPenalty`
- `inferenceLoadScore`
- `structureComplexityScore`

Phase-2 quality dimensions:

- `minimumLengthGate`
- `discourseDensityGate`
- `distractorPlausibilityGate`
- `transitionComplexityGate`
- `redundancyPenalty`

## Hard TypeTag Fail-Close Set

The current fail-close set is intentionally narrow and only covers the typeTags
that have both repeated quality drift and a clear exam-style anchor baseline.

- READING
  - `R_INSERTION`
  - `R_ORDER`
  - `R_SUMMARY`
- LISTENING
  - `L_SITUATION`
  - `L_LONG_TALK`

For `H2/H3`, these typeTags hard-block publish when the calibration or quality
gate fails.

All other typeTags remain in shadow-evaluation mode for now so the evaluator
can collect trace data without over-blocking inventory.

## TypeTag-Specific Rules

### READING / `R_INSERTION`

- direct clue connectors incur a penalty
- H2/H3 require a minimum sentence floor and word-count floor
- H2/H3 fail when the paragraph is too simple or the insertion slot is too obvious
- simple list-like paragraph progression is not publishable for upper tracks
- at least two plausible distractor slots are expected for upper tracks

### READING / `R_BLANK`

- H2/H3 fail when inference load is too low
- simple paraphrase-only blanks are not publishable for upper tracks

### READING / `R_ORDER`, `R_SUMMARY`, `R_VOCAB`

- H2/H3 require discourse or semantic inference
- direct lexical clue patterns are penalized
- H2/H3 `R_ORDER` / `R_SUMMARY` require a minimum sentence floor and discourse transition load

### LISTENING / `L_RESPONSE`

- exactly two turns are required
- distractor responses must be strong enough to create plausible alternatives
- obvious one-slot answers are penalized

### LISTENING / `L_LONG_TALK`

- H2/H3 require a minimum turn floor and information density floor
- turn/sentence density must stay above the track baseline
- H2/H3 fail when the item is only surface-level information checking

### LISTENING / `L_SITUATION`

- H1/H2/H3 require contextual inference
- surface clue dependence is penalized
- direct-clue-only resolution is not publishable

## Gold Anchor Set

A small gold anchor fixture set is stored at:

- `backend/tests/fixtures/calibration_gold_set.json`

The initial anchor coverage includes pass/fail fixtures for:

- `H2 / R_INSERTION`
- `H2 / L_SITUATION`
- `H3 / R_SUMMARY`
- `H3 / L_LONG_TALK`

These fixtures are regression anchors. The evaluator must keep passing the pass
cases and keep failing the fail cases.

## Operational Effect

- reviewer surfaces must show calibration score, level, warnings, fail reasons,
  rubric version, quality gate version, and override requirement
- quantity is secondary to quality-gated publishability
- `B2.6.19` backfill only counts inventory that clears this gate
