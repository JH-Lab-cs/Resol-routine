# Backend Handoff

This document is the backend handoff baseline for the next chat/session.

## A. Product Overview

- App: Resol Routine
- Target users: Korean learners (middle school grade 3 to high school grade 3)
- Roles:
  - Student
  - Parent
- Tracks:
  - M3
  - H1
  - H2
  - H3

## B. Learning Rules

- Daily routine:
  - LISTENING 3 + READING 3 (fixed total 6)
- Today vocab quiz:
  - 20 questions, 5 options
- Weekly mock exam:
  - LISTENING 10 + READING 10 (total 20)
- Monthly mock exam:
  - LISTENING 17 + READING 28 (total 45)

## C. Current Frontend Status

- Daily quiz flow: implemented
- Vocab + custom vocab CRUD: implemented
- Weekly/monthly mock flows (resume/completion/result/history): implemented
- Wrong notes integration (daily + mock): implemented
- Report schema v5 (export/import): implemented
- Parent home report section:
  - End-user path: placeholder only before backend link rollout
  - File-based report import/export: dev-only QA path remains available

## D. Backend Goals

- Parent-child linking via invite code
- Automatic report sync (student -> parent)
- Content backend service
- Mock exam assembly/orchestration service
- AI generation worker pipeline
- Subscription and entitlement backend

## E. Server Contracts (Must Keep)

- Enum values:
  - Track: `M3`, `H1`, `H2`, `H3`
  - Skill: `LISTENING`, `READING`
  - Mock exam type: `WEEKLY`, `MONTHLY`
  - Wrong reason tag: `VOCAB`, `EVIDENCE`, `INFERENCE`, `CARELESS`, `TIME`
- Report schema:
  - Versioned, strict-guarded
  - Current frontend export target: `schemaVersion = 5`
  - Backward import compatibility required for v1~v5 payloads
  - v5 coverage:
    - `days`
    - `vocabQuiz`
    - `vocabBookmarks`
    - `customVocab.lemmasById`
    - `mockExams.weekly`
    - `mockExams.monthly`
- Composition invariants:
  - Daily: 3 listening + 3 reading
  - Weekly: 10 listening + 10 reading
  - Monthly: 17 listening + 28 reading
- Security/data constraints:
  - Export/import payload must never include copyrighted content text
  - IDs/metadata-only rule must be preserved

## F. Backend Phase-1 Scope

- Authentication
- Parent-child link service
- Sync event ingestion/pipeline
- Report aggregation service
- Content bank schema and APIs
- Mock exam blueprint/publish workflow

## G. Baseline Revision

- Frontend baseline commit: `f3e2956e868d2b5c19a7ee383b460f10db764460`
- CI baseline:
  - Flutter CI green
  - Android smoke green
  - iOS smoke green
  - Run: https://github.com/JH-Lab-cs/Resol-routine/actions/runs/22515570517

## H. Out of Scope for Backend Phase-1

- Real-time sync
- Teacher/admin public console
- Final billing production rollout
- AI auto-publish without human review
- Full content authoring UI

## I. Parent-Child Linking Policy (Phase-1 Default)

- Cardinality:
  - One parent can link multiple children.
  - One child can link up to two parents (configurable server constant).
- Invite code:
  - 6-digit code.
  - One-time use.
  - Expiration: 10 minutes.
- Linking behavior:
  - Parent code entry links immediately in phase-1.
  - Student approval step is out of phase-1 scope.
  - Every link/unlink action must be audit-logged.
- Re-link/unlink:
  - Reusing an already-consumed code is rejected.
  - Unlink must preserve historical study/report data.
  - Re-link after unlink requires a new one-time code.

## J. Sync Model

- Mobile uploads event-level study results, not only final report snapshots.
- Server aggregates parent-facing reports from stored events.
- Export/import JSON remains dev-only QA path before backend rollout.

## K. Content Lifecycle

- Draft generation
- Validation
- Human review
- Publish
- Client consumption

## L. Mock Exam Assembly Rules

- Weekly and monthly mock exams are assembled server-side and published.
- The app consumes published sets, not ad-hoc runtime generation.
- Assembly must preserve:
  - track constraints
  - skill counts
  - type diversity
  - deterministic period keys

## Quick Start References

- Product/source-of-truth spec:
  - `docs/spec.md`
- Agent/development rules:
  - `AGENTS.md`
- Operations and CI/release rules:
  - `docs/operations.md`
