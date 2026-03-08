# Vocabulary Banding Policy

Last updated: 2026-03-08

## Scope

This document freezes the pre-B3 vocabulary metadata and banding policy.

It does not implement user-specific adaptive selection. That remains post-B3 work.

## Required Metadata

`vocab_master` must support the minimum metadata needed to express CSAT-oriented
progression:

- `sourceTag`
  - `CSAT`
  - `SCHOOL_CORE`
  - `USER_CUSTOM`
- `targetMinTrack`
  - nullable
  - one of `M3`, `H1`, `H2`, `H3`
- `targetMaxTrack`
  - nullable
  - one of `M3`, `H1`, `H2`, `H3`
- `difficultyBand`
  - nullable integer `1..5`
- `frequencyTier`
  - nullable integer `1..5`

`USER_CUSTOM` remains separate from curated curriculum/CSAT vocabulary.

## Frozen Progression Rule

- `M3`
  - foundational / high-frequency academic vocabulary
  - expected difficulty band: `1..2`
  - primary source: `SCHOOL_CORE`
- `H1`
  - lower-band CSAT / school-core vocabulary
  - expected difficulty band: `2..3`
  - primary sources: `SCHOOL_CORE`, `CSAT`
- `H2`
  - mid-band CSAT vocabulary plus carry-over review
  - expected difficulty band: `3..4`
  - primary source: `CSAT`
  - carry-over source: `SCHOOL_CORE`
- `H3`
  - upper-band CSAT vocabulary plus spaced review of lower bands
  - expected difficulty band: `4..5`
  - primary source: `CSAT`
  - carry-over sources: `SCHOOL_CORE`, `CSAT`

## Selection Contract (Design-Only)

Pre-B3 and B3 baseline behavior may stay deterministic and non-adaptive.

The frozen rule is:

- selection must first respect the declared track band
- then prefer the track's primary source tags
- then allow carry-over review sources
- then keep difficulty inside the preferred band whenever possible

User-specific scoring based on unseen/wrong/stale history remains outside this
document and is defined separately in `docs/adaptive_selection_design.md`.

## Dev/QA Seed Policy

- starter-pack vocabulary is allowed to remain small
- starter-pack vocabulary must still carry the frozen metadata fields above
- local custom vocabulary created in the app must default to:
  - `sourceTag = USER_CUSTOM`
  - `targetMinTrack = null`
  - `targetMaxTrack = null`
  - `difficultyBand = null`
  - `frequencyTier = null`

## Readiness Threshold

Pre-B3 readiness uses a conservative service threshold:

- each track band should have at least `20` vocab rows eligible for that band
- each row must carry:
  - `sourceTag`
  - `targetMinTrack`
  - `targetMaxTrack`
  - `difficultyBand`
- the current repository still treats vocabulary as local/front-owned metadata
  rather than a backend catalog

That means vocabulary can be audited for readiness, but it is not yet part of
the backend AI backfill flow.

Current implication:

- metadata structure is ready
- deterministic banding policy is ready
- live-service depth is still not ready

## Implementation Timing

- metadata schema expansion: now
- deterministic rule function for tests/docs: now
- adaptive/user-specific selection: after B3 event sync stabilization
