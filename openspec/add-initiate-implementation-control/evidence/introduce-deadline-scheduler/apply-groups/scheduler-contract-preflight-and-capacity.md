# Apply Group Evidence: scheduler-contract-preflight-and-capacity

- Automation: add-initiate-changes
- Change: introduce-deadline-scheduler
- Checkpoint: introduce-deadline-scheduler:apply:scheduler-contract-preflight-and-capacity
- Completed at: 2026-05-25T11:29:11Z
- Result: completed
- Implementation commit: 42bb64b0bb5d5bf3e6187d19d584907a8074d8cc

## Scope

Implemented the first deadline scheduler slice:

- scheduler input gate passes non-`draft_review` compiler packages through unchanged;
- `schedule_draft_review` returns a pure `ScheduledDraftReview` review package for compiler-ready tasks;
- scheduler `needs_input` preflight for missing deadline, invalid dates, invalid capacity/rest/load anchors, and empty schedulable task sets;
- visible default assumptions for start date, deadline type, capacity, existing active load, rest weekdays, unavailable dates, and buffer policy;
- package anchor merge for deadline, capacity, rest weekdays, unavailable dates, existing load, and compiler assumptions;
- inclusive local date window from start through deadline;
- deadline-before-start infeasible review with essential/optional risk math;
- usable capacity from daily capacity, existing load, rest days, and unavailable dates, using 60 minutes as the default;
- basic scheduler statuses `needs_input`, `draft_review`, and `infeasible_review`.

Out of scope for this group:

- 80% planning budget cap;
- deterministic buffer reservation/erosion;
- load-shape placement;
- dependency-aware placement beyond essential-first safety;
- continuation-session splitting;
- fallback-mode metadata;
- canonical infeasibility option effects.

## TDD Record

Initial RED:

- Command: `cd assistant_backend && uv run pytest tests/test_study_plan_scheduling.py -k 'scheduler_input_gate or scheduler_output_shape or scheduler_preflight or scheduler_uses_inclusive or scheduler_computes_capacity'`
- Result: failed with `AttributeError: module 'src.study_plan.scheduling' has no attribute 'schedule_draft_review'`.

Spec-review RED fixes:

- Command: `cd assistant_backend && uv run pytest tests/test_study_plan_scheduling.py -k 'scheduler_input_gate or scheduler_preflight or optional_unscheduled or capacity_gap'`
- Result before fix: failed for unchanged pass-through, missing assumptions, invalid date exceptions, optional unscheduled minutes, and capacity gap math.

Code-quality RED fixes:

- Command: `cd assistant_backend && uv run pytest tests/test_study_plan_scheduling.py -k 'package_anchors or invalid_capacity or invalid_non_deadline or optional_unscheduled or essential_work or capacity_gap or input_gate or missing_invalid'`
- Result before fix: failed for package anchor merge, invalid input recovery, optional risk reporting, essential-first placement, and capacity gap math.
- Command: `cd assistant_backend && uv run pytest tests/test_study_plan_scheduling.py -k 'invalid_capacity_or_rest_days or inclusive_window'`
- Result before fix: failed for invalid container-shaped inputs and deadline-before-start optional/essential math.

Final GREEN:

- `cd assistant_backend && uv run pytest tests/test_study_plan_scheduling.py -k 'input_gate or output_shape or preflight or inclusive or capacity or default'`: 11 passed, 3 deselected.
- `cd assistant_backend && uv run pytest tests/test_study_plan_scheduling.py`: 14 passed.
- `openspec validate introduce-deadline-scheduler --strict`: valid.
- `openspec instructions apply --change introduce-deadline-scheduler --json`: 9/36 complete, 27 remaining.

## Review Record

Spec compliance review:

- Initial result: blocked by P1/P2 findings around unchanged pass-through, `needs_input` assumptions, invalid date parsing, optional risk reporting, and capacity gap math.
- Fixes:
  - Non-draft compiler packages now return as unchanged pass-through payloads.
  - Scheduler recovery paths include visible defaultable assumptions.
  - Invalid start/unavailable/existing-load dates return `needs_input` instead of raising.
  - Optional/stretch unscheduled minutes are reported separately from essential capacity gap.
  - Capacity gap reports missing minutes, not whole unscheduled essential task estimates.
- Final re-review result: APPROVED for tasks 1.1, 1.2, 1.3, 1.4, 1.5, 1.11, 4.1, 4.2, and 4.3.

Code quality review:

- Initial result: blocked by P1/P2 findings around package anchor merge, capacity gap math, essential-first placement, compiler assumption preservation, and invalid preflight inputs.
- Fixes:
  - Scheduler uses package anchors when explicit arguments are absent.
  - Compiler assumptions are preserved and scheduler assumptions are appended.
  - Essential tasks place before optional tasks when capacity is tight.
  - Invalid capacity, rest weekday, unavailable date, and existing-load inputs return focused `needs_input` recovery.
  - Container-shape errors no longer raise exceptions.
  - Deadline-before-start risk math separates essential gap and optional unscheduled minutes.
- Final re-review result: APPROVED. No remaining findings.

## Files Changed

- `assistant_backend/src/study_plan/scheduling.py`
- `assistant_backend/src/study_plan/__init__.py`
- `assistant_backend/tests/test_study_plan_scheduling.py`
- `openspec/changes/introduce-deadline-scheduler/tasks.md`

## Git Safety

Protected unrelated dirty files were present and not touched or staged:

- `docs/agent-workflow.md`
- `openspec/changes/harden-add-initiate-automation-control/design.md`
- `openspec/changes/harden-add-initiate-automation-control/proposal.md`
- `openspec/changes/harden-add-initiate-automation-control/tasks.md`
- `openspec/changes/redesign-study-intake-planning/iteration-records/round-16-split-readiness-review.md`
- `openspec/changes/redesign-study-intake-planning/pre-split-readiness-audit.md`
- `openspec/changes/redesign-study-intake-planning/split-decision.md`
- `openspec/changes/redesign-study-intake-planning/tasks.md`

The run lock was not staged.

## Next Checkpoint

introduce-deadline-scheduler:apply:placement-buffer-splitting-fallback-and-risk
