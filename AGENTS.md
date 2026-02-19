# AGENTS.md (Repository Instructions)

## Source of truth
- Always read `docs/spec.md` before starting any task.
- Treat `docs/spec.md` as the single source of truth for product rules.
- Do NOT edit `docs/spec.md` unless the user explicitly requests a spec change.

## Workflow
- Work in small, reviewable commits.
- Prefer feature-first structure; keep layers clean (UI / state / repository / db).

## Language policy
- App UI strings (buttons, menus, labels, guidance copy) must be written in Korean.
- Question content (prompts, passages/scripts, answer options) must be written in English.
- Explanation fields `whyCorrectKo` and `whyWrongKo` must be written in Korean.

## Non-negotiable checks (before pushing)
Run and paste the full outputs in the task log:
1) `python3 tool/security/check_bidi.py`
2) `dart analyze`
3) `flutter test`

## Data / DB guardrails
- Do not use `jsonDecode/jsonEncode` in UI code. Use Drift TypeConverters or repository-level parsers.
- Never weaken DB constraints that enforce LISTENING/READING invariants.

## Content pack guardrails
- Options must be exactly A..E.
- evidenceSentenceIds must exist in the target script/passage sentences.
- Respect seed hard limits and text limits.
