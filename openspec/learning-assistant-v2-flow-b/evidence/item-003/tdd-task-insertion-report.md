# TDD Report: Manual Task Insertion

OpenSpec change: `introduce-study-plan-adjustment`

Tasks:
- 5.1 Write failing backend tests for inserting an active project task on a selected date with no cascade and red-state recalculation.
- 5.2 Implement task insertion service/route.

## RED

Command:

```bash
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_insert.py -q
```

Result: failed as expected.

Summary:
- Successful insertion tests failed with `404 Not Found` for `POST /api/study-plan-adjustment/projects/{project_id}/tasks`.
- Completed/non-study/not-found project rejection tests failed with `404 Not Found` instead of the intended safe rejection contract.
- Invalid payload tests failed with `404 Not Found` instead of request validation.

This proved the tests were exercising the missing task insertion route/service.

## GREEN

Changes:
- Added `insert_active_study_project_task` in `assistant_backend/src/db/queries.py`.
- Added `POST /api/study-plan-adjustment/projects/{project_id}/tasks` in `assistant_backend/src/routers/study_plan_adjustment.py`.
- Added backend tests in `assistant_backend/tests/test_study_plan_adjustment_insert.py`.

Command:

```bash
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_insert.py -q
```

Result: `7 passed, 2 warnings`.

Behavior verified:
- Active study projects can receive a new unfinished `time` task on the selected date.
- Existing task `scheduled_date` values are unchanged; no cascade or repair runs.
- `study_task_inserted` event is persisted with `project_id`, `task_id`, `scheduled_date`, `target_minutes`, `title`, and `source="manual_insert"`.
- Project Overview recalculates `expected_late=True` when the inserted task lands after the deadline.
- Calendar recalculates `over_capacity=True` when inserted target minutes push a day over capacity.
- Completed study projects, non-study resources, and missing projects are rejected without mutation/event.
- Blank titles and non-positive target minutes are rejected without mutation/event.

## REFACTOR / Verification

No additional refactor was needed after GREEN; the implementation stayed aligned with existing adjustment query/router transaction patterns.

Command:

```bash
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_insert.py assistant_backend/tests/test_study_views_project_overview.py assistant_backend/tests/test_study_views_calendar.py -q
```

Result: `18 passed, 2 warnings`.

Warnings observed:
- Existing third-party deprecation warnings from `google.genai.types` and `langgraph.checkpoint.serde.encrypted`.

## Review Fix: Stable Project Order Fact

Review finding: inserted tasks had no `unit_id` or `units.order_index`, so `move_active_study_task` treated them as no-unit tail tasks. Moving an inserted task could therefore skip later same-project tasks that should cascade by project order.

### RED

Command:

```bash
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_insert.py -q
```

Result: failed as expected.

Summary:
- `test_insert_active_project_task_creates_unfinished_task_without_cascade_and_records_event` failed because the inserted task had `unit_id = None`.
- `test_inserted_task_gets_project_order_fact_so_later_move_cascades_successors` failed because the inserted task sorted with `order_index = None` instead of being placed between same-day and later project tasks.

### GREEN

Fix summary:
- Task insertion now creates a corresponding `units` row with a stable `order_index`.
- The insertion slot is before the first unfinished same-project task scheduled after the selected date, or at the project end when no later task exists.
- Same-project `units.order_index` values at and after the insertion slot are shifted by +1.
- Existing task `scheduled_date` values are unchanged during insertion.

Command:

```bash
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_insert.py -q
```

Result: `8 passed, 2 warnings`.

### REFACTOR / Verification

Commands:

```bash
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_insert.py assistant_backend/tests/test_study_plan_adjustment_move.py assistant_backend/tests/test_study_views_project_overview.py assistant_backend/tests/test_study_views_calendar.py -q
openspec validate introduce-study-plan-adjustment --strict
```

Results:
- `22 passed, 2 warnings`.
- `Change 'introduce-study-plan-adjustment' is valid`.
