# Apply Group Evidence: intake-data-and-idempotency

## Timestamp

2026-05-25T04:44:45Z

## Change

`introduce-study-intake-router`

## Checkpoint

`introduce-study-intake-router:apply:intake-data-and-idempotency`

## Task Group

- Group id: `intake-data-and-idempotency`
- Task ids: `1.1`, `3.1`, `3.2`, `3.3`, `4.5`, `4.6`

## Files Changed

- `assistant_backend/src/db/schema.py`
- `assistant_backend/src/study_plan/intake.py`
- `assistant_backend/tests/test_study_intake_router.py`
- `openspec/changes/introduce-study-intake-router/tasks.md`

## Implementation Commit

- `08104306ceb192cb60fab92e91d9f4a650d4951a`

## TDD Evidence

Initial RED:

- Command: `cd assistant_backend && uv run pytest tests/test_study_intake_router.py -k 'idempotency or non_plan or today_exclusion'`
- Result: failed as expected with `ModuleNotFoundError: No module named 'src.study_plan.intake'`.

Quality-fix RED:

- Command: `cd assistant_backend && uv run pytest tests/test_study_intake_router.py`
- Result: failed as expected with 3 failures proving invalid child inserts could mark parent intake items confirmed and `{}` metadata did not round-trip.

Final GREEN:

- Command: `cd assistant_backend && uv run pytest tests/test_study_intake_router.py`
- Result: passed, 6 tests.

## Implementation Summary

- Added persisted intake tables separate from `resources`, `units`, and `tasks`.
- Added idempotent intake item creation keyed by `client_request_id`.
- Added persistence helpers for reference/later non-plan resources.
- Added persistence helper for material-only active-plan attachments.
- Ensured `immediate_one_off` intake items remain outside Today until explicit later action.
- Added transaction-safe confirmation helpers using `ON CONFLICT(intake_item_id) DO NOTHING` instead of broad `INSERT OR IGNORE`.
- Preserved empty metadata objects through JSON round-trip.

## Verification Commands

- `cd assistant_backend && uv run pytest tests/test_study_intake_router.py`: passed, 6 tests.
- `cd assistant_backend && uv run pytest tests/test_study_plan_router.py tests/test_study_views_today.py`: passed, 12 tests, 2 warnings.
- `openspec validate introduce-study-intake-router --strict`: passed.

## Reviews

Spec compliance review:

- Verdict: approved.
- P0/P1: none.
- P2: source-type coverage can be expanded in later routing group; current generic persistence helper is source-type agnostic.

Code quality review:

- First verdict: changes required.
- Issue: broad `INSERT OR IGNORE` could swallow non-idempotent constraint failures and leave confirmed parent state without child row.
- Fix: targeted conflict handling, explicit transactions, child fetch before parent update, metadata `{}` round-trip.
- Re-review verdict: approved.

## Scope Notes

This group did not implement role recommendation, GitHub preview, draft persistence, scheduling, or UI. Those remain in later groups/changes.

## Result

Completed. The `intake-data-and-idempotency` group is verified and can be marked complete.

## Next Checkpoint

`introduce-study-intake-router:apply:source-preview-and-github-roles`
