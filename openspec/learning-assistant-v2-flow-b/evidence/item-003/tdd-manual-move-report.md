# ITEM-003 Manual Move TDD Report

OpenSpec change: `introduce-study-plan-adjustment`

Scope:
- Task 4.1: failing backend tests for active unfinished task date move with same-project later-task cascade and no cross-project movement.
- Task 4.2: task move service/route with delta cascade, past-date rejection, event persistence, and rollover reset.

Out of scope:
- Tasks 4.3/4.4 deadline editing.
- Tasks 5.x add/delete, 6.x rest-day, 7.x dialogue adjustment, and 8/9 Swift/UI.

## RED

Command:

```bash
cd /Users/cpt/Public/MalDaze
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_move.py -q
```

Expected failure observed:

```text
2 failed
AssertionError: {"detail":"Not Found"}
assert 404 == 200
assert 404 == 400
```

The failing tests covered:
- moving unfinished active `study_project` task `4302` from date A to date B;
- shifting unfinished same-project later task `4303` by the same delta;
- leaving earlier same-project task, completed same-project task, and other-project task unchanged;
- resetting `auto_roll_days`, `last_auto_rolled_at`, and setting `user_adjusted_at` for affected tasks only;
- persisting one `study_task_moved` event with selected task id, affected ids, original/new dates, and `manual_move` source;
- rejecting a target date before the current local day without mutating tasks or events.

## GREEN

Command:

```bash
cd /Users/cpt/Public/MalDaze
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_move.py -q
```

Result:

```text
2 passed, 2 warnings
```

Implementation summary:
- Added `move_active_study_task(db, task_id, new_date, today)` in `assistant_backend/src/db/queries.py`.
- Added `POST /api/study-plan-adjustment/tasks/{task_id}/move` with request body `{ "scheduled_date": "YYYY-MM-DD" }`.
- Added 400 rejection for past target dates, 404 for missing tasks, and 409 for completed/non-active/non-study tasks.
- Persisted successful moves in one transaction with `study_task_moved` event evidence and rollover marker reset for affected tasks.

## REFACTOR

After GREEN, the project-order fallback key was simplified so unit-backed tasks sort by `unit.order_index, scheduled_date, id`, and tasks without a unit use a deterministic `scheduled_date, id` fallback.

Command:

```bash
cd /Users/cpt/Public/MalDaze
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_move.py -q
```

Result:

```text
2 passed, 2 warnings
```

## Regression

Command:

```bash
cd /Users/cpt/Public/MalDaze
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_move.py assistant_backend/tests/test_study_plan_adjustment_rollover.py assistant_backend/tests/test_study_views_today.py -q
```

Result:

```text
7 passed, 2 warnings
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
- Matches Manual Task Date Move Cascade scenarios for selected task movement, same-project unfinished successor cascade, no cross-project movement, and no completed task movement.
- Matches past-date rejection without mutation.
- Matches mechanical adjustment evidence with selected task, affected ids, original/new dates, and `manual_move` source.
- Matches rolled baseline reset for user-initiated movement.

Code quality:
- Keeps all date mutations and event persistence in a single transaction.
- Avoids touching deadline edit, add/delete, rest-day, dialogue, Swift, UI, and automation progress/state files.
- Uses the existing adjustment router style and DB query layer rather than adding a new service boundary.

## Review Fix: Cascade Past-Date Guard

P2 addressed:
- A move target on today was accepted even when a same-project later-by-order unfinished task would be shifted before today by the same delta.
- Expected contract: reject the whole move with 400 and leave task dates, rollover markers, user adjustment timestamps, and `study_task_moved` events unchanged.

### RED

Command:

```bash
cd /Users/cpt/Public/MalDaze
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_move.py -q
```

Expected failure observed:

```text
FAILED assistant_backend/tests/test_study_plan_adjustment_move.py::test_move_rejects_when_cascade_would_shift_affected_task_before_today_without_mutation
AssertionError: {"task_id":4404,"source":"manual_move","affected_count":2,"changes":[{"task_id":4404,"project_id":4401,"old_date":"2026-05-25","new_date":"2026-05-24"},{"task_id":4405,"project_id":4401,"old_date":"2026-05-24","new_date":"2026-05-23"}]}
assert 200 == 400
```

### GREEN

Command:

```bash
cd /Users/cpt/Public/MalDaze
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_move.py -q
```

Result:

```text
3 passed, 2 warnings
```

Implementation summary:
- Added a guard after all manual-move `changes` are computed and before any task update or event insert.
- If any affected task would have `new_date < today`, `TaskMovePastDateError` is raised through the existing 400 route path and the transaction rolls back.

### Regression

Command:

```bash
cd /Users/cpt/Public/MalDaze
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_move.py assistant_backend/tests/test_study_plan_adjustment_rollover.py assistant_backend/tests/test_study_views_today.py -q
```

Result:

```text
8 passed, 2 warnings
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
