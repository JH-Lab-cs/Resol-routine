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
  - `L_RESPONSE -> content-v1-listening-response-skeleton`
  - `L_SITUATION -> content-v1-listening-situation`
- READING
  - `R_INSERTION -> content-v1-reading-insertion`
  - `R_BLANK -> content-v1-reading-blank`
  - `R_ORDER -> content-v1-reading-order`
  - `R_SUMMARY -> content-v1-reading-summary`
  - `R_VOCAB -> content-v1-reading-vocab`

The following track-specific quality profiles now override the generic hard
template path:

- `H2 / L_SITUATION -> content-v1-listening-situation-contextual`
  - generation mode: `L_SITUATION_CONTEXTUAL_SKELETON`
  - generation profile: `H2_L_SITUATION_CONTEXTUAL`
  - timeout override: `60s`
- `H1 / R_BLANK -> content-v1-reading-blank-discourse`
  - generation mode: `R_BLANK_DISCOURSE_OUTLINE`
  - generation profile: `H1_R_BLANK_DISCOURSE`
  - timeout override: `60s`
- `H1 / R_ORDER -> content-v1-reading-order-discourse`
  - generation mode: `R_ORDER_DISCOURSE_OUTLINE`
  - generation profile: `H1_R_ORDER_DISCOURSE`
  - timeout override: `60s`

These timeout overrides are profile-local only. The global provider timeout
does not change for other typeTags.

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

### Observed outcomes before the L_RESPONSE redesign

| TypeTag | Model | Valid Rate | Materialize Rate | Publishable Rate | Estimated Cost USD | Publishable / Dollar | Decision |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| `L_LONG_TALK` | `gpt-5-mini` | 0.0 | 0.0 | 0.0 | 0.002855 | 0.0 | fail |
| `L_LONG_TALK` | `gpt-4.1-mini` | 1.0 | 1.0 | 1.0 | 0.002488 | 401.92926 | fallback approved |
| `L_RESPONSE` | `gpt-5-mini` | 0.0 | 0.0 | 0.0 | 0.004155 | 0.0 | redesign required |
| `L_RESPONSE` | `gpt-4.1-mini` | 0.0 | 0.0 | 0.0 | 0.003528 | 0.0 | redesign required |
| `R_INSERTION` | `gpt-5-mini` | 0.0 | 0.0 | 0.0 | 0.002855 | 0.0 | fail |
| `R_INSERTION` | `gpt-4.1-mini` | 1.0 | 1.0 | 1.0 | 0.002488 | 401.92926 | fallback approved |

## Active Policy

- Keep `gpt-5-mini` as the global default model
- Allow `gpt-4.1-mini` fallback only for:
  - `L_LONG_TALK`
  - `R_INSERTION`
- `L_RESPONSE` now uses a dedicated generation mode:
  - prompt template: `content-v1-listening-response-skeleton`
  - generation mode: `L_RESPONSE_SKELETON`
  - compiler version: `l-response-compiler-v1`
- `L_RESPONSE` dedicated mode has now produced a live publishable item with
  `gpt-5-mini`, so fallback remains disabled
- Even when a model path is schema-valid, the item still needs to pass the
  publish-time track calibration and quality gates. Hard-deficit model routing
  does not bypass quality policy.

## Calibration/Quality Gate Coupling

- `schema valid != publishable`
- `publishable = schema valid + calibration pass + quality gate pass`
- Current calibration rubric version:
  - `2026-03-15-b2.6.20`
- Current quality gate version:
  - `2026-03-15-b2.6.20`
- `H2/H3` fail-close typeTags:
  - `R_INSERTION`
  - `R_ORDER`
  - `R_SUMMARY`
  - `L_SITUATION`
  - `L_LONG_TALK`
- `M3/H1` warning budget:
  - warning count `<= 1`: reviewer publish allowed
  - warning count `>= 2`: `overrideRequired = true`
  - `length_too_short` / `direct_clue_too_strong` are immediate block reasons
- Gold anchor regression fixtures:
  - `backend/tests/fixtures/calibration_gold_set.json`

This means backfill quality now depends on both model routing and the
post-generation hard gate. `B2.6.19` should only count inventory that clears
both.

## L_RESPONSE Dedicated Generation Mode

`L_RESPONSE` is no longer generated through the generic canonical content path.

The model now returns a response-item skeleton only:

- exactly 2 turns
- `responsePromptSpeaker`
- `correctResponseText`
- `distractorResponseTexts` (exactly 4)
- `evidenceTurnIndexes`
- `whyCorrectKo`
- `whyWrongKoByOption`

The server then compiles the final canonical payload deterministically:

- fixed stem: `What is the most appropriate response to the last speaker?`
- deterministic option layout:
  - `A = correct`
  - `B..E = distractors`
- deterministic `answerKey`
- deterministic transcript sentence ids
- deterministic `evidenceSentenceIds`

This keeps the default model on `gpt-5-mini` while making the strict JSON
contract substantially smaller and more validator-friendly.

## Dedicated Quality Profiles

`B2.6.20` adds type-specific generation redesign for the three remaining
quality-sensitive deficits:

- `H2 / L_SITUATION`
  - contextual skeleton only
  - minimum 3 turns
  - final-turn-only solutions are invalid
  - at least 2 plausible distractors required
- `H1 / R_BLANK`
  - discourse outline only
  - minimum 130+ words after compile
  - paraphrase-only blanks are invalid
  - discourse shift must be explicit
- `H1 / R_ORDER`
  - discourse outline only
  - minimum 130+ words after compile
  - simple chronology / cue-word-only ordering is invalid
  - at least 2 plausible distractor orders required

These profiles do not change the default model. They narrow the generation task
so `gpt-5-mini` is more likely to clear the publish-time quality gate.

The next operational step after this redesign is `B2.6.21`, which should only
count inventory that clears both the calibration gate and these dedicated
profiles.

## Korean Exam Style Policy Freeze

`B2.6.22` does not change the model-selection baseline.

- default model remains `gpt-5-mini`
- approved fallback remains limited to:
  - `L_LONG_TALK -> gpt-4.1-mini`
  - `R_INSERTION -> gpt-4.1-mini`

What changes is the generation-style policy frozen at:

- `backend/shared/generation/korean_exam_generation_policy_v1.json`
- loader: `backend/app/services/generation_policy_service.py`
- reference: `docs/korean_exam_generation_policy.md`

This policy separates:

- subtype taxonomy
- grade style
- discourse mode
- family mode

and defines:

- `wordCountBand`
- `sentenceCountBand`
- `wordsPerSentenceBand`
- eight difficulty axes

The model policy therefore stays fixed, while the exam-style target becomes
more precise. `B2.6.23` is the stage that should wire this policy into the live
generator path.

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
