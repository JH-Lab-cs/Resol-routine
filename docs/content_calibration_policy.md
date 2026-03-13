# Content Calibration Policy

## Scope

This document freezes the publish-time calibration policy for backend-authored
content.

The core rule is:

- `schema valid != publishable`
- `publishable = schema valid + calibration pass`

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

- `M3/H1`
  - calibration fail is stored and surfaced
  - reviewer warning mode is allowed
  - publish is still permitted
- `H2/H3`
  - calibration fail blocks publish
  - batch publish must surface the item in `failedItems`

Rubric version:

- `2026-03-13-b2.6.16`

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

## TypeTag-Specific Rules

### READING / `R_INSERTION`

- direct clue connectors incur a penalty
- H2/H3 fail when the paragraph is too simple or the insertion slot is too obvious
- at least two plausible distractor slots are expected for upper tracks

### READING / `R_BLANK`

- H2/H3 fail when inference load is too low
- simple paraphrase-only blanks are not publishable for upper tracks

### READING / `R_ORDER`, `R_SUMMARY`, `R_VOCAB`

- H2/H3 require discourse or semantic inference
- direct lexical clue patterns are penalized

### LISTENING / `L_RESPONSE`

- exactly two turns are required
- distractor responses must be strong enough to create plausible alternatives
- obvious one-slot answers are penalized

### LISTENING / `L_LONG_TALK`

- turn/sentence density must stay above the track baseline
- H2/H3 fail when the item is only surface-level information checking

### LISTENING / `L_SITUATION`

- H1/H2/H3 require contextual inference
- surface clue dependence is penalized

## Operational Effect

- reviewer surfaces must show calibration score, level, warnings, fail reasons,
  and rubric version
- future backfill rounds only add meaningful inventory when the candidate also
  clears this calibration gate
