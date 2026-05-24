# ITEM-003 Rollover TDD Report

OpenSpec change: `introduce-study-plan-adjustment`

Scope:
- Task 3.1: failing backend tests for idempotent unfinished-task rollover into the current local day without same-project cascade.
- Task 3.2: rollover service and route, auto-roll counters, and event persistence.

Out of scope:
- Tasks 3.3/3.4 Today rolled badge payload.
- Manual move, deadline edit, add/delete, rest days, dialogue adjustment.

## RED

Command:

```bash
cd /Users/cpt/Public/MalDaze/assistant_backend
.venv/bin/python -m pytest tests/test_study_plan_adjustment_rollover.py -q
```

Expected failure observed:

```text
2 failed
AssertionError: {"detail":"Not Found"}
assert 404 == 200
```

The failing tests covered:
- overdue unfinished active `study_project` task moves to today's local date;
- same-project future task does not cascade;
- completed task, completed project task, and non-study task do not move;
- `auto_roll_days` and `last_auto_rolled_at` update;
- one `study_task_rolled_over` event is persisted;
- repeated same-day call is idempotent and does not duplicate event evidence.

## GREEN

Command:

```bash
cd /Users/cpt/Public/MalDaze/assistant_backend
.venv/bin/python -m pytest tests/test_study_plan_adjustment_rollover.py -q
```

Result:

```text
2 passed, 2 warnings
```

Implementation summary:
- Added `rollover_unfinished_study_tasks(db, today)` in `assistant_backend/src/db/queries.py`.
- Added `POST /api/study-plan-adjustment/rollover`.
- Registered the adjustment router in `assistant_backend/src/main.py`.

## Regression

Command:

```bash
cd /Users/cpt/Public/MalDaze/assistant_backend
.venv/bin/python -m pytest tests/test_study_plan_adjustment_rollover.py tests/test_study_plan_adjustment_schema.py tests/test_study_views_project_overview.py tests/test_study_views_calendar.py -q
```

Result:

```text
15 passed, 2 warnings
```

Command:

```bash
cd /Users/cpt/Public/MalDaze
openspec validate introduce-study-plan-adjustment --strict
```

Result:

```text
Change 'introduce-study-plan-adjustment' is valid
```

## Review

Spec compliance:
- Matches Unfinished Task Rollover scenarios for move-to-today, no successor cascade, auto-roll count, and same-day idempotence.
- Persists event payload with `task_id`, `resource_id`, `original_date`, `new_date`, `rolled_days`, and `source`.

Code quality:
- Keeps mutation in a single DB transaction.
- Leaves unrelated adjustment features untouched.
- Leaves Today rolled badge payload for tasks 3.3/3.4.
