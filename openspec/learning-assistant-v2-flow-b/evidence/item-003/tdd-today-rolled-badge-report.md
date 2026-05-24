# ITEM-003 Today Rolled Badge TDD Report

OpenSpec change: `introduce-study-plan-adjustment`

Scope:
- Task 3.3: Today exposes rolled-day count and threshold badge facts.
- Task 3.4: Today view payloads and task completion rollover-marker reset behavior.

Out of scope:
- Manual move, deadline edit, add/delete, rest days, dialogue adjustment.
- Swift API/ViewModel/UI.

## RED

Before production-code changes, focused tests were updated/added for:
- `GET /api/study-views/today` runs rollover before reading Today facts.
- A three-day rolled task returns `rolled_day_count: 3` and `show_rolled_badge: true`.
- A same-project future task is not moved by Today rollover.
- A Today task with `auto_roll_days = 2` returns `show_rolled_badge: false`.
- Completing a rolled task resets `auto_roll_days` and `last_auto_rolled_at`, and clears any active rolled badge.

Command:

```bash
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_views_today.py assistant_backend/tests/test_study_views_completion.py -q
```

Expected failure observed:

```text
4 failed, 5 passed, 2 warnings
```

Expected failure details:
- Existing Today payload lacked `rolled_day_count` and `show_rolled_badge`.
- Overdue task `3601` did not appear in Today because Today had not invoked rollover.
- Completion left `auto_roll_days = 4` and `last_auto_rolled_at = 2026-05-24`.

Note:
- One existing completion assertion was aligned with the already-present `expected_late: false` project overview field before production-code edits, so RED evidence reflects only this task's missing behavior.

## GREEN

Command:

```bash
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_views_today.py assistant_backend/tests/test_study_views_completion.py -q
```

Result:

```text
9 passed, 2 warnings
```

Implementation summary:
- `assistant_backend/src/routers/study_views.py` now calls `rollover_unfinished_study_tasks(db, date.today())` before querying Today.
- `assistant_backend/src/db/queries.py` now adds `rolled_day_count` and `show_rolled_badge` to Today task payloads.
- `complete_task` now resets `auto_roll_days` to `0` and `last_auto_rolled_at` to `NULL` when completing a task, including idempotent duplicate completion calls.

## Regression

Command:

```bash
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_views_today.py assistant_backend/tests/test_study_views_completion.py assistant_backend/tests/test_study_plan_adjustment_rollover.py -q
```

Result:

```text
11 passed, 2 warnings
```

Command:

```bash
openspec validate introduce-study-plan-adjustment --strict
```

Result:

```text
Change 'introduce-study-plan-adjustment' is valid
```

## Review

Spec compliance:
- Satisfies rollover-before-Today-read for active unfinished study tasks.
- Exposes rolled-day count and threshold badge facts with threshold `rolled_day_count >= 3`.
- Preserves same-project future task dates during Today-triggered rollover.
- Clears active rolled badge state after task completion by resetting persisted markers.

Code quality:
- Reuses the existing rollover service instead of duplicating mutation logic.
- Keeps completion reset in `complete_task`, preserving existing route behavior.
- Leaves existing Today semantics intact: completed tasks scheduled today can still appear, but they are not active and no longer carry a rolled badge after completion.

Remaining risk:
- Swift consumers are outside this subtask and still need their later API/model/UI coverage.
