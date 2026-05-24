# ITEM-002 Backend Project Overview TDD Report

Timestamp: 2026-05-23T18:25:26Z

Change: `introduce-study-views`

Tasks:

- 2.5 Write failing backend tests for Project Overview active summaries and completed history.
- 2.6 Implement project overview queries/routes using current task/unit/resource facts.

## RED

Initial RED:

- `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_views_project_overview.py -q`
- Result: 3 failures because `GET /api/study-views/projects` returned `404 Not Found`.

Review-driven RED:

- Same-unit multiple tasks initially reported progress from unit status instead of task facts.
- A no-unit completion without `actual_minutes` initially reported `actual_minutes=0` instead of target-minute fallback.
- A zero-task active study project with stale `resources.total_units=5` initially reported `total_units=5` instead of task-derived `0`.

## GREEN

Implemented backend Project Overview behavior:

- Added deterministic `GET /api/study-views/projects`.
- Added `get_study_project_overview()` query helper.
- Response returns `active_projects` and `completed_projects`.
- Summaries include title, completed count, total count, progress ratio, target minutes, actual minutes, deadline, and status.
- Progress is computed from persisted task facts: completed tasks divided by current task count.
- `actual_minutes` uses completed task facts with `COALESCE(actual_minutes, target_minutes, 0)`.
- Completion persists target fallback minutes to `tasks.actual_minutes` when no explicit actual minutes are supplied.
- Archived projects and non-study resources are excluded.
- Automatic completed-project archive remains deferred to tasks 2.9/2.10.

## REFACTOR

- Removed stale resource cache fallback from Project Overview progress totals.
- Loosened same-unit final-task tests so they do not freeze the future 2.9/2.10 auto-archive behavior.
- Kept the first-task unfinished-project guard to ensure this slice does not prematurely auto-complete projects.

## Reviews

First code-quality review requested changes:

- Do not freeze final-task active-project behavior in 2.5/2.6.
- Use task facts rather than unit status for progress.
- Normalize actual-minute fallback semantics.

Second code-quality review requested two small fixes:

- Zero-task projects must not fall back to stale `resources.total_units`.
- Completion tests must not lock out future automatic archive behavior.

Final spec review: APPROVED.

Final code-quality review after the second repair found no critical issues; the remaining recommendations were applied before marking tasks complete.

## Verification

- `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_views_project_overview.py tests/test_study_views_completion.py -q`: `9 passed, 2 warnings`.
- `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_views_today.py tests/test_resource_management.py -q`: `14 passed, 2 warnings`.
- `git diff --check`: PASS.
