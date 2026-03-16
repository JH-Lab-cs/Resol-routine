# Korean Exam Generation Policy

## Scope

This document freezes the Korean-style exam generation policy introduced in
`B2.6.22`.

The policy is stored in:

- `backend/shared/generation/korean_exam_generation_policy_v1.json`
- loader: `backend/app/services/generation_policy_service.py`

The policy is a frozen planning contract for generator hardening. It does not
run backfill by itself.

## Core Principle

Do not control grade difficulty with one shared average length.

Use:

- `grade × subtype × discourse_mode`
- plus family overrides:
  - `official_high1`
  - `official_high2`
  - `official_high3`
  - `official_high3_hard`
  - `indepth_high3`
  - `middle3_official`
  - `middle3_bridge`

Difficulty is not just length. The frozen axes are:

- `wordCount`
- `syntaxDepth`
- `abstractionLevel`
- `evidenceDistance`
- `referentAmbiguity`
- `distractorOverlap`
- `discourseDensity`
- `clueDirectness`

Each axis is normalized on a `1..5` scale where higher means more demanding.

## Subtype Taxonomy

Listening subtypes:

- `L_PURPOSE`
- `L_OPINION`
- `L_GIST`
- `L_PICTURE_MATCH`
- `L_ACTION`
- `L_PRICE_CALC`
- `L_REASON`
- `L_MENTION_CHECK`
- `L_CONTENT_MATCH`
- `L_TABLE_SELECTION`
- `L_SHORT_RESPONSE`
- `L_LONG_RESPONSE`
- `L_SITUATION`
- `L_LONG_TALK_TOPIC`
- `L_LONG_TALK_DETAIL`

Reading subtypes:

- `R_PURPOSE`
- `R_TONE_MOOD`
- `R_CLAIM`
- `R_UNDERLINED_MEANING`
- `R_MAIN_IDEA`
- `R_TITLE`
- `R_CHART_MATCH`
- `R_FACT_MATCH`
- `R_NOTICE_MISMATCH`
- `R_NOTICE_MATCH`
- `R_GRAMMAR`
- `R_VOCAB`
- `R_BLANK`
- `R_IRRELEVANT`
- `R_ORDER`
- `R_INSERTION`
- `R_SUMMARY`
- `R_LONG_PASSAGE_INFO`
- `R_LONG_PASSAGE_NARRATIVE`

Canonical type tags remain unchanged in the backend. The policy maps each
subtype to an existing canonical type tag so later generator stages can stay
compatible with the current delivery contract.

## Grade Styles

- `middle1`
  - short, concrete, direct clue inside one sentence
- `middle2`
  - slightly longer, basic inference starts
- `middle3_official`
  - close to entry-level high1, but explicit connectors stay visible
- `middle3_bridge`
  - `0.85~0.95` of high1 reading length, inference slightly raised
- `H1`
  - standard-centered, explicit connectors, partial-restatement distractors
- `H2`
  - hard-centered, referent tracking and clue-distance matter more
- `H3`
  - hard to killer, more abstraction, paraphrase distance, and compressed logic

Middle-school policy is not just reduced word count. It also lowers cognitive
load, referent ambiguity, and distractor overlap.

## Discourse Modes

- `practical_notice`
- `email_letter`
- `biography`
- `expository`
- `narrative`
- `dialogue`
- `academic_argument`
- `mixed_expository_narrative`

The same subtype can shift in sentence shape, clue distance, and distractor
strategy depending on discourse mode.

## Length Bands

Each lookup returns:

- `wordCountBand`
- `sentenceCountBand`
- `wordsPerSentenceBand`

Every band is `min / target / max`.

Official high-school reading anchors are frozen from the current user-provided
range analysis:

- High1
  - `18`: `91~137`
  - `21`: `135~184`
  - `31~34`: `123~174`
  - `36~39`: `154~178`
  - `41~42`: `214~275`
  - `43~45`: `303~320`
- High2
  - `18`: `99~129`
  - `21`: `150~180`
  - `31~34`: `127~183`
  - `36~39`: `141~186`
  - `41~42`: `221~257`
  - `43~45`: `285~365`
- High3
  - `18`: `105~122`
  - `21`: `151~193`
  - `31~34`: `140~175`
  - `36~39`: `160~194`
  - `41~42`: `236~275`
  - `43~45`: `346~398`

The JSON keeps these ranges as official anchors. Lower grades use explicit
banded derivatives, not one shared fallback average.

## Family Modes

- `official_high3`
  - mid-band official baseline with relatively transparent vocabulary
- `official_high3_hard`
  - similar length, but stronger abstraction, clue distance, and distractor overlap
- `indepth_high3`
  - more compressed than official, but denser and more abstract
- `middle3_bridge`
  - transition family toward high1, not just a shorter middle3 official set

## Next Stage

- `B2.6.23`
  - consume this policy directly in generator hardening
- `B2.6.24`
  - run calibrated backfill only after the generator uses this policy in live execution
