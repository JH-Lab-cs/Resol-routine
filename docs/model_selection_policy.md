# Model Selection Policy for Hard Deficit TypeTags

## Scope

This document defines the current model-selection policy for content backfill
when a deficit is concentrated in hard typeTags.

It does not change the default content generation model for the rest of the
pipeline.

## Default Model

- Default content generation model: `gpt-5-mini`
- Default prompt family: `content-v1`

The default path stays in place unless a hard typeTag proves materially better
under a limited fallback evaluation.

## Hard TypeTag Prompt Hardening

The following typeTags use dedicated hardened prompt templates:

- LISTENING
  - `L_LONG_TALK -> content-v1-listening-longtalk`
  - `L_RESPONSE -> content-v1-listening-response`
  - `L_SITUATION -> content-v1-listening-situation`
- READING
  - `R_INSERTION -> content-v1-reading-insertion`
  - `R_BLANK -> content-v1-reading-blank`
  - `R_ORDER -> content-v1-reading-order`
  - `R_SUMMARY -> content-v1-reading-summary`
  - `R_VOCAB -> content-v1-reading-vocab`

Prompt hardening requirements:

- strict JSON only
- options `A..E` only, with unique option text
- `answerKey` in `A..E`
- evidence ids must point to real sentences
- LISTENING transcript / turn / sentence alignment must be preserved
- explanation fields must be complete enough for reviewer validation

## Fallback Evaluation Rule

- Default model stays `gpt-5-mini`
- Optional fallback model: `gpt-4.1-mini`
- `gpt-5.4` is excluded from this phase

Fallback is evaluated only for hard-deficit typeTags and only in small batches.

Recommended batch size:

- `maxTargetsPerRun <= 2`
- `maxCandidatesPerRun <= 4`

## Decision Metric

The decision metric is:

- `publishable item per dollar`

Support metrics:

- valid candidate rate
- materialize success rate
- publishable item rate
- latency
- estimated cost USD

Fallback is allowed only when a typeTag-specific evaluation shows a materially
better publishable item per dollar outcome than the hardened default path.

## Current Evaluation Baseline

Evaluation label:

- `b2-6-8-ab-20260310125300`

### Observed outcomes

| TypeTag | Model | Valid Rate | Materialize Rate | Publishable Rate | Estimated Cost USD | Publishable / Dollar | Decision |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| `L_LONG_TALK` | `gpt-5-mini` | 0.0 | 0.0 | 0.0 | 0.002855 | 0.0 | fail |
| `L_LONG_TALK` | `gpt-4.1-mini` | 1.0 | 1.0 | 1.0 | 0.002488 | 401.92926 | fallback approved |
| `L_RESPONSE` | `gpt-5-mini` | 0.0 | 0.0 | 0.0 | 0.004155 | 0.0 | fail |
| `L_RESPONSE` | `gpt-4.1-mini` | 0.0 | 0.0 | 0.0 | 0.003528 | 0.0 | fallback not approved |
| `R_INSERTION` | `gpt-5-mini` | 0.0 | 0.0 | 0.0 | 0.002855 | 0.0 | fail |
| `R_INSERTION` | `gpt-4.1-mini` | 1.0 | 1.0 | 1.0 | 0.002488 | 401.92926 | fallback approved |

## Active Policy

- Keep `gpt-5-mini` as the global default model
- Allow `gpt-4.1-mini` fallback only for:
  - `L_LONG_TALK`
  - `R_INSERTION`
- Do not enable fallback yet for:
  - `L_RESPONSE`

## Operational Notes

- Fallback must remain limited to the approved hard typeTags.
- Large backfill runs are still out of scope for this policy.
- Every evaluation run must store:
  - `modelName`
  - `promptTemplateVersion`
  - `typeTag`
  - `candidateCount`
  - `retryCount`
  - `validCandidateRate`
  - `materializeSuccessRate`
  - `publishableItemRate`
  - `estimatedCostUsd`
  - `publishableItemPerDollar`
