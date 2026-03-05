# resol_routine

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Git Hooks

```bash
git config core.hooksPath .githooks
```

## Project Spec

- `docs/spec.md` is the single source of truth for product rules.
- Every ticket must start by reading `docs/spec.md`.
- Required checks: `python3 tool/security/check_bidi.py`, `dart analyze`, `flutter test`.

## Operations Policy

- CI release smoke artifacts are for compile validation only and must never be distributed.
- Production store releases must use dedicated signing pipelines:
  - Android: keystore / Play signing required.
  - iOS: certificate / provisioning / App Store Connect signing required.
- CI smoke and release pipelines must remain separated.
- Parent report auto-sync remains disabled until backend linking is available.
  - End-user path: hidden.
  - File-based import/export: dev-only QA path.

See `/Users/ijihun/Resol routine/docs/operations.md` for the full policy.
