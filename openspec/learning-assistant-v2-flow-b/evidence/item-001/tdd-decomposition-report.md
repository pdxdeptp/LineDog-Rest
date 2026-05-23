# ITEM-001 TDD Decomposition Report

## Scope

- OpenSpec change: `introduce-study-plan-foundation`
- Tasks: 3.3, 3.4
- Spec area: D29 decomposition pipeline
- Worker: `019e5581-dfd0-7602-81d4-8578e4dff2e6`

## RED Evidence

- Command: `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_plan_decomposition.py -q`
- Result: `5 failed`
- Failure reason: expected `ModuleNotFoundError: No module named 'src.study_plan.decomposition'`
- Meaning: D29 decomposition pipeline helper did not exist yet.

## GREEN Evidence

- Command: `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_plan_decomposition.py tests/test_study_plan_clarification.py tests/test_study_plan_scheduling.py tests/test_study_plan_lifecycle.py -q`
- Result: `18 passed`
- OpenSpec validation: `openspec validate introduce-study-plan-foundation --strict` passed.

## Implementation Summary

- Added `assistant_backend/src/study_plan/decomposition.py`.
- Added `assistant_backend/tests/test_study_plan_decomposition.py`.
- Pipeline now:
  - records the D29 stage order: `extract_structure`, `estimate_difficulty`, `estimate_durations`, `merge_tasks`, `schedule_draft`;
  - accepts completed or skipped clarification payloads;
  - extracts ordered units from source data;
  - preserves known duration estimates;
  - uses a deterministic fallback duration for missing estimates;
  - merges ordered units into ordered draft tasks;
  - reuses D24 scheduling through `plan_initial_draft_schedule`;
  - uses `generic_fallback` for unknown material with usable units;
  - returns a user-visible failure state when no usable structure exists.

## Reviews

### Spec Compliance

- Review: `APPROVED`.
- Blocking issues: none.
- Non-blocking notes:
  - difficulty estimation is intentionally coarse;
  - stage output is a summary rather than full intermediate artifacts;
  - network fetch, LLM handlers, API/UI wiring, and true URL preview remain later tasks.

### Code Quality

- Review: `APPROVED`.
- Blocking issues: none.
- Non-blocking follow-ups:
  - narrow substring-based material type matching before broader inputs;
  - add coverage for `structure` fallback inputs;
  - ensure API/lifecycle wiring gates on `status == "draft_ready"` before creating drafts;
  - add deterministic tie-break and no-mutation regression tests.

## Status

Tasks 3.3 and 3.4 are complete.
