# TDD Rest Day Settings Report

## Scope

- OpenSpec change: `introduce-study-plan-adjustment`
- Tasks: 6.1, 6.2
- Files touched:
  - `assistant_backend/tests/test_study_plan_adjustment_rest_days.py`
  - `assistant_backend/tests/test_study_views_calendar.py`
  - `assistant_backend/src/db/queries.py`
  - `assistant_backend/src/routers/study_plan_adjustment.py`
  - `openspec/changes/introduce-study-plan-adjustment/tasks.md`

## RED

Command:

```bash
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_rest_days.py assistant_backend/tests/test_study_views_calendar.py -q
```

Result:

- Failed as expected before implementation.
- Failure mode: rest-day settings endpoints returned `404 {"detail":"Not Found"}` and Calendar day payloads did not expose `rest_day` / `available_capacity_minutes`.
- Summary: `10 failed, 1 passed`.

Covered failing scenarios:

- `GET /api/study-plan-adjustment/rest-days` returns defaults from `system_state`: weekly `[5]`, one-off `[]`.
- `PUT /api/study-plan-adjustment/rest-days` normalizes duplicate/unsorted weekly weekdays and one-off dates, persists settings, and records `study_rest_days_updated` add/remove evidence.
- Invalid weekday/date payloads are rejected without mutating `system_state` or writing events.
- Calendar marks weekly and one-off rest days and exposes zero available capacity.
- Removing a rest day updates settings and Calendar availability without moving existing active task dates.

## GREEN

Command:

```bash
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_rest_days.py assistant_backend/tests/test_study_views_calendar.py -q
```

Result:

- Initial GREEN run found one test expectation issue: `2026-08-01` is Saturday, so the default weekly rest weekday `[5]` correctly marks it as `rest_day: true`.
- After correcting that assertion: `11 passed`.
- Warnings were existing third-party deprecation warnings from `google.genai` / `langgraph`.

Implementation summary:

- Added `get_study_rest_day_settings` and `update_study_rest_day_settings` in `assistant_backend/src/db/queries.py`.
- Added `GET /api/study-plan-adjustment/rest-days` and `PUT /api/study-plan-adjustment/rest-days` in `assistant_backend/src/routers/study_plan_adjustment.py`.
- PUT uses complete replacement semantics, normalizes sorted unique weekdays/dates, and stores JSON arrays in `study_rest_weekdays` / `study_rest_dates`.
- PUT records `study_rest_days_updated` with old/new weekly and one-off values, added/removed facts, and `source=manual_rest_day_settings`.
- Calendar now exposes `rest_day` and `available_capacity_minutes`; rest days use zero learning capacity and do not move tasks.
- D27 +1 day cascade was intentionally not implemented; it remains scoped to tasks 6.3/6.4.

## REFACTOR / Verification

Refactor:

- Hardened rest weekday normalization so corrupted persisted state values are skipped instead of breaking read paths.
- Hardened one-off date normalization so corrupted persisted state date strings are skipped instead of breaking read paths.

Commands:

```bash
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_rest_days.py assistant_backend/tests/test_study_views_calendar.py -q
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_rest_days.py assistant_backend/tests/test_study_views_calendar.py assistant_backend/tests/test_study_plan_adjustment_schema.py -q
openspec validate introduce-study-plan-adjustment --strict
```

Results:

- Focused rest-day and Calendar regression: `11 passed`.
- Full requested pytest command: `13 passed`.
- OpenSpec strict validation: `Change 'introduce-study-plan-adjustment' is valid`.
- Warnings: existing third-party deprecation warnings from `google.genai` / `langgraph`.

Task checklist:

- 6.1 checked complete.
- 6.2 checked complete.

## Review Fix

Code Quality Review found one P1 regression after Calendar started returning
`rest_day` and `available_capacity_minutes`: existing insert/delete tests with
exact day payload assertions still expected the old shape.

RED command:

```bash
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_insert.py assistant_backend/tests/test_study_plan_adjustment_delete.py -q
```

RED result:

- `2 failed, 10 passed`
- Failures were exact payload shape mismatches in insert/delete Calendar
  assertions.

GREEN fix:

- Updated the insert/delete tests to assert the enriched Calendar day payload.
- The expected helper derives the default Saturday rest-day capacity from the
  asserted date so the tests do not become dependent on the day generated from
  `date.today()`.

GREEN command:

```bash
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_insert.py assistant_backend/tests/test_study_plan_adjustment_delete.py -q
```

GREEN result:

- `12 passed`
