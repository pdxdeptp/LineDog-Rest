# ITEM-003 Backend Schema And Red-State Facts TDD Report

Scope: OpenSpec change `introduce-study-plan-adjustment`, tasks 2.1-2.4 only.

## RED 2.1

Command:

```bash
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_schema.py -q
```

Result: failed as expected.

Summary:

- New DB initialization did not create `tasks.auto_roll_days`.
- Existing DB initialization did not migrate `auto_roll_days`, `last_auto_rolled_at`, or `user_adjusted_at`.
- Default rest-day system state keys were absent.

## GREEN 2.2

Command:

```bash
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_schema.py -q
```

Result: `2 passed`.

Summary:

- Added task auto-roll metadata columns to `SCHEMA_SQL`.
- Added `study_rest_weekdays = [5]` and `study_rest_dates = []` defaults.
- Added an `init_db` migration helper that alters existing `tasks` tables when the new columns are missing.

## RED 2.3

Command:

```bash
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_views_project_overview.py assistant_backend/tests/test_study_views_calendar.py -q
```

Result: failed as expected.

Summary:

- Project Overview did not expose `expected_late`.
- The new Calendar regression for over-capacity recalculation after persisted task fact changes passed against the existing calendar helper; the command remained RED because Project Overview lacked the new expected-late facts.

## GREEN 2.4

Command:

```bash
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_views_project_overview.py assistant_backend/tests/test_study_views_calendar.py -q
```

Result: `11 passed`.

Summary:

- Project Overview now derives `expected_late` from active study projects with unfinished tasks scheduled after the project deadline.
- Completed projects and non-study resources do not create expected-late state.
- Red-state view reads do not mutate task dates.
