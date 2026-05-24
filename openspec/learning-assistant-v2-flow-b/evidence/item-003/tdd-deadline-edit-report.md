# TDD Report: Project Deadline Editing

OpenSpec change: `introduce-study-plan-adjustment`

Tasks:
- 4.3 Write failing backend tests for active project deadline edit that recalculates expected-late state without moving tasks.
- 4.4 Implement project deadline edit service/route.

## RED

Command:

```bash
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_deadline.py -q
```

Result: failed as expected.

Summary:
- `test_deadline_edit_recalculates_expected_late_without_moving_tasks` failed with `404 Not Found` for `POST /api/study-plan-adjustment/projects/4501/deadline`.
- Missing/null/empty deadline rejection tests also failed with `404 Not Found` instead of the intended validation behavior.
- Completed/non-study rejection test failed with `404 Not Found` instead of the intended safe rejection.

This proved the tests were exercising the missing deadline edit route/service.

## GREEN

Changes:
- Added `update_active_study_project_deadline` in `assistant_backend/src/db/queries.py`.
- Added `POST /api/study-plan-adjustment/projects/{project_id}/deadline` in `assistant_backend/src/routers/study_plan_adjustment.py`.
- Added backend tests in `assistant_backend/tests/test_study_plan_adjustment_deadline.py`.

Command:

```bash
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_deadline.py -q
```

Result: `5 passed, 2 warnings`.

Behavior verified:
- Active study project deadline updates `resources.deadline`.
- Existing task `scheduled_date` values are unchanged.
- Project Overview recalculates `expected_late` from persisted task facts after early and later deadline edits.
- `study_project_deadline_updated` events are persisted with project id, old/new deadline, and `source="deadline_edit"`.
- Missing, null, and empty deadlines return 422 without mutation/event.
- Completed study projects and non-study resources return 409 without mutation/event.

## REFACTOR

No additional refactor was needed after GREEN; the implementation stayed small and aligned with existing adjustment query/router patterns.

Command:

```bash
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_deadline.py assistant_backend/tests/test_study_views_project_overview.py -q
```

Result: `12 passed, 2 warnings`.

Warnings observed:
- Existing third-party deprecation warnings from `google.genai.types` and `langgraph.checkpoint.serde.encrypted`.

## Review Fix: Deadline Removal Explanation

Review finding: the `Deadline cannot be removed` scenario requires an explanatory response, not only a default 422 validation error. The response now explains that v2 active plans require deadlines for late-state detection.

### RED

Command:

```bash
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_deadline.py -q
```

Result: failed as expected.

Summary:
- Missing deadline `{}` returned Pydantic `Field required` without the required explanation.
- Null deadline returned Pydantic date validation without the required explanation.
- Empty deadline returned Pydantic date parsing validation without the required explanation.
- Existing no-mutation/no-event assertions stayed in the same test.

### GREEN

Command:

```bash
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_deadline.py -q
```

Result: `5 passed, 2 warnings`.

Fix summary:
- `UpdateProjectDeadlineRequest.deadline` now accepts `date | None = None`.
- Empty string is normalized to missing via a request-model validator.
- The route rejects missing/null/empty deadlines with 422 and detail `v2 active plans require deadlines for late-state detection`.
- Valid dates still parse normally and reach the deadline edit service.

### REFACTOR / Verification

Commands:

```bash
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_deadline.py assistant_backend/tests/test_study_views_project_overview.py -q
openspec validate introduce-study-plan-adjustment --strict
```

Results:
- `12 passed, 2 warnings`.
- `Change 'introduce-study-plan-adjustment' is valid`.
