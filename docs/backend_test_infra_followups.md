# Backend Test Infra Follow-ups

## Ticket: SQLITE-FK-CYCLE-TEARDOWN (Closed)

### Context

Backend tests currently pass, but SQLite teardown emits an SAWarning about cyclic foreign key dependencies when dropping tables.

### Current Status

- Resolution date: 2026-03-02 (KST)
- Severity: Non-blocking (resolved in current baseline)
- Functional impact: None
- Operational impact: No teardown warning observed in current pytest run

### Scope

- Keep this as a guardrail note for future schema changes.
- If cyclic FK warnings reappear, open a new infra ticket instead of patching feature tickets.

### Outcome

- Current backend test baseline shows no cyclic drop warning in teardown.
- Existing behavior and constraints remain intact.
- Full test suite still passes.

### Suggested Technical Direction

- Break known schema cycles using targeted `use_alter=True` on cyclic foreign keys where appropriate, or equivalent safe migration/model refactoring.
- Keep production schema semantics unchanged.
- Re-run:
  - `cd backend && uv run pytest -q`
  - `cd backend && python3 -m compileall app tests alembic`
  - `python3 tool/security/check_bidi.py`
