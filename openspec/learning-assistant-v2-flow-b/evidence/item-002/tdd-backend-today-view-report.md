# TDD Evidence: Backend Today Study View

## Scope

- OpenSpec change: `introduce-study-views`
- Tasks: 2.1, 2.2
- Files changed:
  - `assistant_backend/tests/test_study_views_today.py`
  - `assistant_backend/src/db/queries.py`
  - `assistant_backend/src/routers/study_views.py`
  - `assistant_backend/src/main.py`

## RED

- Worker added `test_today_study_view_returns_persisted_active_project_tasks_without_morning_agent`.
- RED command:
  - `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_views_today.py -q`
- Expected RED result:
  - `404 Not Found` for `/api/study-views/today`.
- RED proved the endpoint/query did not exist and the test would catch the missing v2 Today view surface.

## GREEN

- Added `get_today_study_view_tasks(db, target_date)` to read deterministic task/project/unit facts from SQLite.
- Added `assistant_backend/src/routers/study_views.py` with `GET /api/study-views/today`.
- Registered `study_views.router` in `assistant_backend/src/main.py`.
- The query filters to:
  - today's `scheduled_date`,
  - `resources.status = 'active'`,
  - `resources.type = 'study_project'`.
- The route does not call the morning agent or any LLM path.

## Reviews

- Spec compliance review: APPROVED.
  - Confirmed Today Study View scenarios in tasks 2.1/2.2 are met.
  - Confirmed inactive/completed/archived and non-study resources are excluded by tests.
- Code quality review: APPROVED.
  - No blocking issues.
  - Non-blocking suggestion recorded: a future hardening test could guard direct imports of `src.agents.morning_agent.run_morning_agent`, and the unit join could additionally constrain `u.resource_id = t.resource_id`.

## Verification

- Backend Today view:
  - `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_views_today.py -q`
  - Result: `1 passed, 2 warnings`.
- Backend regression:
  - `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_plan_router.py tests/test_study_plan_lifecycle.py tests/test_resource_management.py -q`
  - Result: `27 passed, 2 warnings`.
- Whitespace:
  - `git diff --check`: PASS.

## Remaining Scope

- Task completion idempotency and project progress refresh remain tasks 2.3 and 2.4.
- Project overview, calendar load, Swift API/ViewModel/UI, and app verification remain pending.
