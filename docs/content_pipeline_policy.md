# Content Pipeline Policy

This policy defines minimum safety and quality gates for generated learning content.

## 1) Lifecycle

- Draft generation
- Validation
- Human review
- Publish
- Client consumption

Auto-publish without human review is out of scope for backend phase-1.

Implementation note:
- Lifecycle status enum stays minimal (`DRAFT`, `PUBLISHED`, `ARCHIVED`).
- Validation/review progress is tracked with trace fields (`validator_version`, `validated_at`, `reviewer_identity`, `reviewed_at`).
- Publish is allowed only when trace-field gates are satisfied.
- Terms like `VALIDATED`, `IN_REVIEW`, and `APPROVED` are operational checkpoints only.
  They are not persisted lifecycle enum states.

## 2) Validation Gates

- Track/skill invariants must pass
- Option set must be exactly A..E for question content
- Evidence sentence references must resolve to valid source sentence IDs
- Text-length constraints must pass
- Hidden/bidi unicode checks must pass

## 3) Review Requirements

- Human reviewer approves educational quality and safety
- Reviewer confirms no policy-prohibited text leakage into report/export pathways
- Reviewer confirms track/skill/type diversity targets for publish batches

## 4) Publish Rules

- Only validated and reviewed content can be published
- Published content must be immutable by version
- Rollback path must exist for each publish batch

## 5) Mock Exam Assembly Policy

- Weekly/monthly sets are assembled server-side from published content
- Assembly must satisfy:
  - track compatibility
  - fixed skill counts
  - type diversity
  - deterministic period keys

## 6) Audit and Traceability

- Each publish batch must keep:
  - generator version
  - validator version
  - reviewer identity
  - publish timestamp
- Assembly results must be reproducible from stored inputs and rules
