# ITEM-002 Backend Automatic Completed Project Archive TDD Report

Timestamp: 2026-05-23T19:02:26Z

Change: `introduce-study-views`

Tasks:

- 2.9 Write failing backend tests for automatic completed project archive/history when the last unfinished task completes.
- 2.10 Implement completed-project transition and event persistence without hard-deleting history.

## RED

Command:

- `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_views_completion.py -q`

Observed failure:

- New test `test_final_study_project_task_completes_project_preserves_history_and_is_idempotent` failed because completing the final active `study_project` task left the resource `active` instead of `completed`.

## GREEN

Implemented backend automatic completed-project transition:

- `complete_task()` now evaluates active `study_project` completion in the same SQLite transaction as task completion.
- When the project has tasks and no unfinished tasks remain, the resource status transitions from `active` to `completed`.
- A single `resource_completed` event is inserted with `source: task_completion`.
- Duplicate task completion returns the original `completed_at` and does not insert duplicate `task_completed` or `resource_completed` events.
- Non-study resources do not trigger this auto-completion path.
- Resource, unit, task, and event records remain persisted.
- Completed projects disappear from active Today and active Project Overview and appear in Project Overview completed history.

## REFACTOR

- Kept the transition in `complete_task()` to avoid a split transaction between task completion and project archive state.
- Preserved existing manual resource-complete behavior.
- Avoided any delete path for automatic completion.

## Reviews

- Spec compliance review: APPROVED.
- Code quality review: APPROVED.

Non-blocking note:

- A future test could exercise two concurrent duplicate completion requests; current sequential duplicate coverage plus `BEGIN IMMEDIATE` protects the intended path.

## Verification

- `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_views_completion.py tests/test_study_views_project_overview.py tests/test_study_views_today.py -q`: `12 passed, 2 warnings`.
- `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_views_calendar.py tests/test_resource_management.py -q`: `16 passed, 2 warnings`.
- `git diff --check`: PASS.
