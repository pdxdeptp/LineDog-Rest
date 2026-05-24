# ITEM-002 Backend Calendar Load TDD Report

Timestamp: 2026-05-23T19:02:26Z

Change: `introduce-study-views`

Tasks:

- 2.7 Write failing backend tests for Calendar load aggregation over a date window and over-capacity marking.
- 2.8 Implement read-only calendar load query/route.

## RED

Command:

- `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_views_calendar.py -q`

Observed failure:

- 3 tests failed because `GET /api/study-views/calendar?start=...&end=...` returned `404 Not Found`.

## GREEN

Implemented backend Calendar Load behavior:

- Added deterministic `GET /api/study-views/calendar?start=YYYY-MM-DD&end=YYYY-MM-DD`.
- Added `get_study_calendar_load()` query helper.
- Calendar returns an inclusive date window with one bucket per day.
- Each bucket includes scheduled active study task count, total target minutes, completed task count, and `over_capacity`.
- Only active `study_project` tasks are included.
- Completed projects, archived projects, and non-study resources are excluded.
- `target_minutes` null values count as `0`.
- Capacity reads `system_state.daily_capacity_min` and falls back to `60` for missing, invalid, or non-positive values.
- `end < start` returns `400`.

## REFACTOR

- Kept Calendar Load strictly read-only: no task mutation, resource mutation, event insert, reschedule, LLM, or morning-agent invocation.
- Existing view routes remain additive and deterministic.

## Reviews

- Spec compliance review: APPROVED.
- Code quality review: APPROVED.

Non-blocking notes:

- Add a dedicated `end < start` regression test later if Calendar API validation grows.
- Consider a maximum date-window guard if this endpoint becomes externally exposed or accepts untrusted long ranges.
- Read-only tests can be broadened to cover more columns, though the implementation is currently SELECT-only.

## Verification

- `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_views_calendar.py -q`: `3 passed, 2 warnings`.
- `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_views_today.py tests/test_study_views_completion.py tests/test_study_views_project_overview.py tests/test_resource_management.py -q`: `23 passed, 2 warnings`.
- `git diff --check`: PASS.
