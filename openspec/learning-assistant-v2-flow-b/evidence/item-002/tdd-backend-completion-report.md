# ITEM-002 Backend Completion TDD Report

Timestamp: 2026-05-23T18:25:26Z

Change: `introduce-study-views`

Tasks:

- 2.3 Write failing backend tests for task completion idempotency, progress update, unit completion, and view refresh facts.
- 2.4 Implement the completion update path needed by v2 views without double-counting duplicate completions.

## RED

Initial failing coverage was added in `assistant_backend/tests/test_study_views_completion.py`.

Observed failing behavior:

- Duplicate completion generated a new `completed_at` value instead of preserving the original completion timestamp.
- The completion path lacked v2 view refresh coverage against `/api/study-views/today`.

After spec review requested changes, additional RED coverage was added:

- Completing an unknown task must return `404` and must not persist a fake `task_completed` event.
- Completing one task while other project tasks remain unfinished must not prematurely mark the resource completed or emit `resource_completed`.
- Completing two tasks linked to the same unit must not double-count `completed_units`.

## GREEN

Implemented backend completion behavior:

- `complete_task()` now runs completion inside a SQLite transaction.
- Duplicate completion returns the original `completed_at` and does not rewrite progress or events.
- Missing task IDs raise `TaskNotFoundError`, which the task router maps to `404`.
- Linked units are marked completed on first task completion.
- `completed_units` increments only when the linked unit was not already completed.
- `actual_minutes_total` increments for each non-duplicate completed task.
- Automatic project/resource completion remains out of scope for 2.3/2.4 and is deferred to tasks 2.9/2.10.
- Today view returns persisted completion facts after completion.

## REFACTOR

- Introduced `TaskNotFoundError` to make the unknown task case explicit.
- Kept the existing task route response shape while making error handling deterministic.
- Avoided adding project archive behavior in this slice to preserve the OpenSpec scope boundary.

## Reviews

Initial spec review requested changes because the first implementation attempted to complete/archive the resource in the 2.3/2.4 slice and did not handle unknown task IDs safely.

Second-pass reviews:

- Spec compliance review: APPROVED.
- Code quality review: APPROVED.

Non-blocking note:

- Future design work should clarify whether unit `actual_minutes` should reflect only the first completed task for that unit or the aggregate across all tasks tied to the unit.

## Verification

- `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_views_completion.py -q`: `3 passed, 2 warnings`.
- `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_views_today.py tests/test_resource_management.py tests/test_study_plan_lifecycle.py -q`: `19 passed, 2 warnings`.
- `git diff --check`: PASS.
