# API Contract Notes (Pre-OpenAPI)

This note captures frontend-backend contracts that must remain stable while formal OpenAPI is prepared.

## Enum Contracts

- Track: `M3`, `H1`, `H2`, `H3`
- Skill: `LISTENING`, `READING`
- MockExamType: `WEEKLY`, `MONTHLY`
- WrongReasonTag: `VOCAB`, `EVIDENCE`, `INFERENCE`, `CARELESS`, `TIME`

## Composition Contracts

- Daily: 6 fixed items (`LISTENING` x3 + `READING` x3)
- Weekly mock: 20 fixed items (`LISTENING` x10 + `READING` x10)
- Monthly mock: 45 fixed items (`LISTENING` x17 + `READING` x28)

## Report Schema Contract

- Current export target: `schemaVersion = 5`
- Import compatibility required for v1~v5 during rollout window
- v5 fields in active use:
  - `days`
  - `vocabQuiz`
  - `vocabBookmarks`
  - `customVocab.lemmasById`
  - `mockExams.weekly`
  - `mockExams.monthly`

## Security/Data Handling Contract

- IDs/metadata only in exported/imported payloads
- Never include copyrighted content text:
  - prompts/options/passages/scripts/explanations
  - vocab meaning/example text
- Hidden/bidi/zero-width unicode validation must be enforced on user-controlled fields

## Sync Contract Direction

- Backend ingest unit is event-level results, not only final report snapshots
- Parent report views must be server-aggregated from ingested events

## Parent Feature Rollout Contract

- Before backend child-link rollout:
  - parent auto-sync report is hidden on user path
  - file import/export remains dev-only QA path
