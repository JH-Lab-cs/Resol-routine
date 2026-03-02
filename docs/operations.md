# Operations Notes

This document defines non-negotiable operational rules for CI smoke builds and release flows.

For backend production readiness, runtime secret handling, migration operations, backup/restore,
and observability rollout status, see:

- `docs/backend_production_readiness.md`

## 1) CI Release Smoke Artifacts Are Not Deployable

- Android release smoke in CI is a compile validation step.
- iOS release smoke in CI (`--no-codesign`) is a compile/link validation step.
- Artifacts produced by CI smoke must never be used for store distribution.

## 2) Production Release Requires Dedicated Signing Pipelines

- Android production release must go through a signing pipeline with keystore / Play signing.
- iOS production release must go through a signing pipeline with certificate, provisioning profile, and App Store Connect process.
- CI smoke and production release pipelines must stay separated.

## 3) Parent Report Availability Before Backend Linking

- Parent report auto-sync is not supported until backend child-linking is enabled.
- End-user UI must keep this feature hidden until backend rollout is complete.
- File-based report import/export remains available only through dev-only QA tools.

## 4) CI Environment Visibility (Required Logs)

To reduce triage time for environment-related failures, CI must print:

- `flutter --version`
- `dart --version`
- `xcodebuild -version` (iOS job)

## 5) Android Smoke Signing Fallback Scope

- Android release smoke fallback signing exists only to validate buildability in CI.
- Team process must block any distribution path that uses debug-signed release artifacts.
