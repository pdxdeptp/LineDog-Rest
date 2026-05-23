# ITEM-001 TDD Scheduling Report

## Scope

- OpenSpec change: `introduce-study-plan-foundation`
- Tasks: 2.3, 2.4
- Spec area: D24 initial draft scheduling, D26 rest-day behavior, capacity/late status honesty
- Worker: `019e556b-5c7f-7531-9de3-d907f076f82d`

## RED Evidence

### First RED

- Command: `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_plan_scheduling.py -q`
- Result: expected failure with `ModuleNotFoundError: No module named 'src.study_plan.scheduling'`
- Meaning: the new D24 scheduling helper did not exist yet.

### Review-Driven RED

- Spec compliance review found the first implementation behaved as greedy next-fit packing, not D24 spread.
- Added RED test for a roomy date window:
  - start: `2026-06-01`
  - deadline: `2026-06-04`
  - capacity: `120`
  - four ordered `60` minute tasks
  - expected dates: `2026-06-01`, `2026-06-02`, `2026-06-03`, `2026-06-04`
- Failure summary: the second task landed on `2026-06-01`, proving early concentration instead of spread.

## GREEN Evidence

- Command: `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_plan_scheduling.py tests/test_study_plan_lifecycle.py -q`
- Result: `8 passed in 0.04s`
- Broader local verification command: `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_plan_scheduling.py tests/test_study_plan_lifecycle.py tests/test_resource_management.py -q`
- Result: `21 passed, 2 warnings in 1.77s`
- OpenSpec validation: `openspec validate introduce-study-plan-foundation --strict` passed.
- Diff hygiene: `git diff --check` passed.

## Implementation Summary

- Added `assistant_backend/src/study_plan/scheduling.py`.
- Added `assistant_backend/tests/test_study_plan_scheduling.py`.
- Scheduler now:
  - maps ordered draft tasks deterministically across available non-rest days;
  - skips default Saturday rest days;
  - preserves project-internal order;
  - ignores `existing_daily_minutes` for placement;
  - uses existing load only to mark over-capacity days;
  - marks `expected_late` when scheduled dates exceed the required deadline;
  - returns pure data and does not mutate unrelated project/task state.

## Reviews

### Spec Compliance

- First review: `CHANGES_REQUIRED`.
- Blocking issue: greedy next-fit packing did not satisfy D24 spread/average distribution.
- Re-review: `APPROVED`.
- Remaining non-blocking gaps: custom `rest_weekdays`, all-rest invalid config, `start_date > deadline`, single task greater than capacity, string date input, and broader API/lifecycle integration coverage.

### Code Quality

- Review: `APPROVED`.
- Blocking issues: none.
- Non-blocking follow-ups:
  - add edge tests before exposing helper as a wider integration boundary;
  - clarify mapping input ordering or prefer sequence/order-index input;
  - consider `TypedDict`/`Literal` return types before API serialization;
  - validate `rest_weekdays` values are in `0..6`.

## Status

Tasks 2.3 and 2.4 are complete.
