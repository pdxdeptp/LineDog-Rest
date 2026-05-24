# TDD Rest Day Cascade Report

## Scope

- OpenSpec change: `introduce-study-plan-adjustment`
- Tasks: 6.3, 6.4
- Files touched:
  - `assistant_backend/tests/test_study_plan_adjustment_rest_days.py`
  - `assistant_backend/src/db/queries.py`
  - `openspec/changes/introduce-study-plan-adjustment/tasks.md`

## RED

Command:

```bash
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_rest_days.py::test_adding_new_rest_days_cascades_unfinished_active_study_tasks_chronologically -q
```

Result:

- Failed as expected before implementation.
- Failure mode: newly added rest days persisted but did not move active unfinished study tasks.
- Key assertion: task `7602` stayed on `2026-05-25` with `auto_roll_days=2` instead of moving to `2026-05-27` with rollover metadata reset.
- Summary: `1 failed`.

Covered failing scenario:

- Adding one-off rest date `2026-05-25` and weekly weekday Tuesday `1` creates newly affected occurrences `2026-05-25` then `2026-05-26`.
- Occurrences are applied chronologically, so unfinished active study tasks on/after both occurrences move twice.
- Tasks before the first occurrence, completed tasks, tasks in completed study projects, and non-study tasks do not move.
- Affected tasks reset `auto_roll_days` to `0`, clear `last_auto_rolled_at`, and set `user_adjusted_at`.
- A dedicated `study_rest_day_cascaded` event records occurrence-level affected task ids plus final task date deltas.

## GREEN

Command:

```bash
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_rest_days.py::test_adding_new_rest_days_cascades_unfinished_active_study_tasks_chronologically -q
```

Result:

- `1 passed`.
- Warnings were existing third-party deprecation warnings from `google.genai` / `langgraph`.

Implementation summary:

- Added chronological rest-day cascade inside `update_study_rest_day_settings`.
- Added future occurrence derivation for newly added weekly rest weekdays and one-off dates on/after the local current day.
- Deduplicated same-day weekly/one-off occurrences.
- For each occurrence, shifted unfinished tasks from active `study_project` resources with `scheduled_date >= occurrence_date` by `+1 day`.
- Reset affected rollover metadata and stamped `user_adjusted_at`.
- Wrote a dedicated `study_rest_day_cascaded` event with `affected_task_ids`, per-occurrence `date_delta_days`, and final task-level deltas.

## REFACTOR / Verification

Commands:

```bash
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_rest_days.py -q
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_move.py assistant_backend/tests/test_study_plan_adjustment_rest_days.py -q
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_*.py -q
```

Results:

- Rest-day focused tests: `8 passed`.
- Move/rest regression: `11 passed`.
- Backend study-plan adjustment suite: `32 passed`.
- Warnings were existing third-party deprecation warnings from `google.genai` / `langgraph`.

Review notes:

- Spec compliance review passed for D27 rest-day cascade behavior in tasks 6.3/6.4.
- Code quality review found no blocking issues.
- Remaining risk: the endpoint still uses process-local `date.today()` for the route default, matching the existing rollover/move boundary pattern; direct service calls can pass `today` for deterministic tests.

## Review Fix

Review result: `CHANGES_REQUESTED`.

Issues addressed:

- P1: weekly recurring rest days only generated the next occurrence instead of each affected future occurrence.
- P2: dates already effective under old rest-day settings could cascade again when added through the other setting type.
- P2: adding a rest day with no affected tasks wrote a noisy `study_rest_day_cascaded` event.

RED command:

```bash
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_rest_days.py::test_adding_weekly_rest_day_cascades_each_future_occurrence_until_plan_horizon assistant_backend/tests/test_study_plan_adjustment_rest_days.py::test_new_one_off_date_already_covered_by_old_weekly_rest_day_does_not_cascade_again assistant_backend/tests/test_study_plan_adjustment_rest_days.py::test_adding_rest_day_with_no_affected_tasks_does_not_record_cascade_event -q
```

RED result:

- `3 failed`.
- Multi-week weekly cascade moved the future task from `2026-06-03` to `2026-06-04`, proving only the first Tuesday occurrence was applied instead of both `2026-05-26` and `2026-06-02`.
- Old weekly Monday plus new one-off Monday moved task `8001` from `2026-05-25` to `2026-05-26`, proving effective old rest days could be cascaded again.
- A one-off rest date with no affected tasks still wrote a `study_rest_day_cascaded` event.

GREEN fix:

- The cascade helper now derives an explicit horizon from the current maximum scheduled date among active unfinished `study_project` tasks.
- Newly added weekly weekdays expand into every future occurrence from `today` through that horizon.
- Candidate occurrences already covered by old weekly or old one-off rest settings are skipped.
- Empty affected occurrences are omitted, and no cascade event is written unless at least one task actually moved.

GREEN command:

```bash
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_rest_days.py::test_adding_weekly_rest_day_cascades_each_future_occurrence_until_plan_horizon assistant_backend/tests/test_study_plan_adjustment_rest_days.py::test_new_one_off_date_already_covered_by_old_weekly_rest_day_does_not_cascade_again assistant_backend/tests/test_study_plan_adjustment_rest_days.py::test_adding_rest_day_with_no_affected_tasks_does_not_record_cascade_event -q
```

GREEN result:

- `3 passed`.

Review-fix verification:

```bash
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_rest_days.py -q
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_*.py -q
openspec validate introduce-study-plan-adjustment --strict
git diff --check
```

Result:

- `11 passed`.
- `35 passed`.
- OpenSpec strict validation: PASS.
- `git diff --check`: PASS.

Re-review:

- Spec Compliance Re-review: PASS.
- Code Quality Re-review: PASS with only P3 scale/test-style observations.
