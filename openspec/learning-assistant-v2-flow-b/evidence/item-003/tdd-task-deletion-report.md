# TDD Task Deletion Report

## Scope

- OpenSpec change: `introduce-study-plan-adjustment`
- Tasks: 5.3, 5.4
- Files touched:
  - `assistant_backend/tests/test_study_plan_adjustment_delete.py`
  - `assistant_backend/src/db/queries.py`
  - `assistant_backend/src/routers/study_plan_adjustment.py`
  - `openspec/changes/introduce-study-plan-adjustment/tasks.md`

## RED

Command:

```bash
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_delete.py -q
```

Result:

- Failed as expected before implementation.
- Failure mode: all three deletion tests received `404 {"detail":"Not Found"}` because `DELETE /api/study-plan-adjustment/tasks/{task_id}` did not exist yet.

Covered failing scenarios:

- Deleting one unfinished active study task removes only that task, preserves later same-project task dates, writes `study_task_deleted`, and Calendar recalculates lighter day load from persisted facts.
- Deleting the last unfinished task marks the project completed, removes it from active overview, preserves completed task/resource facts, and includes it in completed history.
- Completed task, completed project task, non-study task, and missing task are rejected without mutation or deletion events.

## GREEN

Command:

```bash
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_delete.py -q
```

Result:

- `3 passed`
- Warnings were existing third-party deprecation warnings from `google.genai` / `langgraph`.

Implementation summary:

- Added `delete_active_study_task` service in `assistant_backend/src/db/queries.py`.
- Added `TaskDeleteNotAllowedError` for safe 409 rejection.
- Added `DELETE /api/study-plan-adjustment/tasks/{task_id}` route in `assistant_backend/src/routers/study_plan_adjustment.py`.
- Service only deletes unfinished tasks whose resource is an active `study_project`.
- Service does not cascade or reschedule successor tasks.
- Service records `study_task_deleted` with `project_id`, `task_id`, `scheduled_date`, `target_minutes`, `title`, `source=manual_delete`, and `project_completed`.
- If no unfinished tasks remain, service marks the project resource completed and records `resource_completed` with `source=manual_delete`.
- Units/resources and completed task facts are preserved for completed history.

## REFACTOR / Verification

Final checks:

```bash
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_delete.py assistant_backend/tests/test_study_views_project_overview.py assistant_backend/tests/test_study_views_calendar.py -q
openspec validate introduce-study-plan-adjustment --strict
```

Results:

- Backend focused regression: `14 passed`
- OpenSpec strict validation: `Change 'introduce-study-plan-adjustment' is valid`
- Warnings: existing third-party deprecation warnings from `google.genai` / `langgraph`.

Task checklist:

- 5.3 checked complete.
- 5.4 checked complete.

## Code Review Fixes

Review feedback:

- P1: Last unfinished task deletion completed the resource by status only, leaving stale canonical `resources.total_units` / `completed_units` facts and a dangling pending unit.
- P2: Deletion changed Today/task/project facts without invalidating `briefing_{today}`.

### RED

Command:

```bash
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_delete.py -q
```

Result:

- Failed as expected after adding regression coverage.
- Failure modes:
  - `briefing_{today}` remained in `system_state`.
  - Completed resource retained stale `total_units`.
  - Deleting the only task left stale resource/unit facts.

Added regression coverage:

- Any successful delete clears today's briefing cache while preserving other briefing dates.
- Deleting the last unfinished task removes the deleted task's orphan pending unit, preserves completed unit/task history, and syncs completed resource counters.
- Deleting the only task in a project completes the resource without stale total-unit facts or dangling pending units.

### GREEN

Command:

```bash
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_delete.py -q
```

Result:

- `4 passed`
- Warnings were existing third-party deprecation warnings from `google.genai` / `langgraph`.

Implementation summary:

- `delete_active_study_task` now deletes the task's unit only when the unit is orphaned, pending, and not completed history.
- Resource `total_units` and `completed_units` are resynced from remaining units after deletion.
- Today's briefing cache key is invalidated after successful deletion.

### REFACTOR / Final Verification

Commands:

```bash
assistant_backend/.venv/bin/pytest assistant_backend/tests/test_study_plan_adjustment_delete.py assistant_backend/tests/test_study_views_project_overview.py assistant_backend/tests/test_study_views_calendar.py assistant_backend/tests/test_resource_management.py -q
openspec validate introduce-study-plan-adjustment --strict
```

Results:

- Backend focused regression including resource management: `28 passed`
- OpenSpec strict validation: `Change 'introduce-study-plan-adjustment' is valid`
- Warnings: existing third-party deprecation warnings from `google.genai` / `langgraph`.
