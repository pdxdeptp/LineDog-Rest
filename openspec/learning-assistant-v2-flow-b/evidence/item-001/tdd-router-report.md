# ITEM-001 TDD Router Report

## Scope

- OpenSpec change: `introduce-study-plan-foundation`
- Tasks: 3.5, 3.6
- Spec area: backend `/api/study-plan` router for the Swift draft-flow client
- Workers: `019e55a1-19eb-78a3-b1bf-2a918ce1bee4`, `019e55ab-3c8f-70c1-aa68-69c5c2bbddba`

## RED Evidence

### Dead Endpoint RED

- Command: `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_plan_router.py -q`
- Result: `6 failed`
- Failure reason: app lifespan had not registered `/api/study-plan/start`; study-plan endpoints returned 404.

### Existing Load RED

- Command: `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_plan_router.py::test_submit_clarification_marks_existing_load_over_capacity_without_reshuffling tests/test_study_plan_router.py::test_duration_update_recomputes_review_draft_schedule_without_confirming -q`
- Result: `2 failed`
- Failure reason: API responses did not include existing active task load in `over_capacity_days`.

### Stale State RED

- Command: `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_plan_router.py::test_submit_clarification_returns_409_without_tasks_when_draft_stales_before_persist tests/test_study_plan_router.py::test_duration_update_returns_409_without_replacing_tasks_when_draft_stales_before_persist -q`
- Result: `2 failed`
- Failure reason: stale draft status could still leave replaced or newly inserted draft tasks.

## GREEN Evidence

- Command: `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_plan_router.py tests/test_study_plan_decomposition.py tests/test_study_plan_clarification.py tests/test_study_plan_scheduling.py tests/test_study_plan_lifecycle.py -q`
- Result: `27 passed, 2 warnings`
- OpenSpec validation: `openspec validate introduce-study-plan-foundation --strict` passed.
- Diff hygiene: `git diff --check` passed.

## Implementation Summary

- Added `assistant_backend/src/routers/study_plan.py`.
- Added `assistant_backend/tests/test_study_plan_router.py`.
- Registered `study_plan.router` in `assistant_backend/src/main.py`.
- Router now supports:
  - `POST /api/study-plan/start`;
  - `POST /api/study-plan/drafts/{draft_id}/clarification`;
  - `PUT /api/study-plan/drafts/{draft_id}/tasks/{order_index}/duration`;
  - `POST /api/study-plan/drafts/{draft_id}/cancel`;
  - `POST /api/study-plan/drafts/{draft_id}/confirm`.
- Start creates a review draft shell and returns `draft_id + clarification` without active resources/tasks.
- Clarification submit creates review-state draft tasks and preserves skipped/low-calibration metadata.
- Duration update changes draft task minutes and recomputes schedule/capacity status without activation.
- Existing active task load is passed to D24 scheduling so overloaded days are marked without reshuffling draft placement.
- Cancel does not create active data.
- Confirm creates active resource/tasks only after explicit confirmation.
- Clarification submit and duration update use guarded transactions to avoid stale-state half writes.

## Reviews

### Spec Compliance

- First review: `CHANGES_REQUIRED`.
- Blocking issue: existing active load was not reflected in API-level over-capacity status.
- Re-review: `APPROVED`.

### Code Quality

- First review: `CHANGES_REQUIRED`.
- Blocking issue: stale draft state could produce partial task writes.
- Re-review: `APPROVED`.
- Remaining follow-ups:
  - add stricter blank URL validation;
  - consider non-review cancel/confirm boundary tests;
  - consolidate draft repository/lifecycle helpers later.

## Status

Tasks 3.5 and 3.6 are complete.
