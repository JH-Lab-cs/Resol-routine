# Backend Test Infra Follow-ups

## Ticket: SQLITE-FK-CYCLE-TEARDOWN

### Context

Backend tests currently pass, but SQLite teardown emits an SAWarning about cyclic foreign key dependencies when dropping tables.

### Non-blocking Status

- Severity: Non-blocking for feature delivery
- Functional impact: None observed in passing test suite
- Operational impact: Test log noise can hide real regressions

### Scope

- Keep this work out of B1.6 feature implementation.
- Handle as a dedicated test infrastructure task.

### Required Outcome

- Eliminate cyclic drop warning during test teardown.
- Keep existing behavior and constraints intact.
- Preserve full test pass status after the fix.

### Suggested Technical Direction

- Break known schema cycles using targeted `use_alter=True` on cyclic foreign keys where appropriate, or equivalent safe migration/model refactoring.
- Keep production schema semantics unchanged.
- Re-run:
  - `cd backend && uv run pytest -q`
  - `cd backend && python3 -m compileall app tests alembic`
  - `python3 tool/security/check_bidi.py`
