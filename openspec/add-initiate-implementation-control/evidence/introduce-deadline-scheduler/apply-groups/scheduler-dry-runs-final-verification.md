# Apply Group Evidence: scheduler-dry-runs-final-verification

- Automation: add-initiate-changes
- Change: introduce-deadline-scheduler
- Checkpoint: introduce-deadline-scheduler:apply:scheduler-dry-runs-final-verification
- Completed at: 2026-05-25T12:28:41Z
- Result: completed
- Implementation commit: 59533f970ae2f988c3edd504e3ae65e5b314edc4

## Scope

Completed task 4.12 and final verification for `introduce-deadline-scheduler`.

In scope:

- Feasible resume/project packaging dry-run fixture.
- Infeasible easyagent source-understanding rebuild dry-run fixture.
- Capacity math surfaced through scheduler risk report.
- Final full scheduler test run and strict OpenSpec validation.

Out of scope:

- UI rendering and option controls remain in downstream `redesign-add-initiate-ui`.
- Cross-change contract to UI is the next checkpoint and was not executed in this apply group.

## TDD Record

RED:

- Added dry-run tests for:
  - resume/project packaging with 285 essential minutes, 300 available execution minutes, one reserved buffer day, and `draft_review`;
  - easyagent hard-deadline source-understanding rebuild with 525 essential minutes, 300 available execution minutes, 225-minute gap, no `accept_late_finish`, and no standalone `reduce_scope`.
- Initial dry-run run failed because the risk report did not expose `essential_work_minutes` or `available_execution_capacity_minutes`.

GREEN:

- Added the two capacity-math fields to `ScheduleRiskReport`.
- Populated them for normal scheduling and deadline-before-start infeasible reviews.
- Adjusted the easyagent dry-run expectation to include `accept_buffer_risk`, because the scheduler intentionally shows buffer erosion in that fixture.
- Marked task 4.12 complete.

REFACTOR:

- Kept the change limited to risk-report visibility and tests.
- No scheduling placement rules, activation behavior, UI behavior, or compiler behavior were changed.

## Verification

- `cd assistant_backend && uv run pytest tests/test_study_plan_scheduling.py -k 'dry_run or resume_packaging or easyagent_rebuild'`: 2 passed, 33 deselected.
- `cd assistant_backend && uv run pytest tests/test_study_plan_scheduling.py`: 35 passed.
- `openspec validate introduce-deadline-scheduler --strict`: valid.
- `openspec instructions apply --change introduce-deadline-scheduler --json`: 36/36 tasks complete, state all_done.
- `git diff --check -- assistant_backend/src/study_plan/scheduling.py assistant_backend/tests/test_study_plan_scheduling.py openspec/changes/introduce-deadline-scheduler/tasks.md`: no whitespace errors.

## Files

- `assistant_backend/src/study_plan/scheduling.py`
- `assistant_backend/tests/test_study_plan_scheduling.py`
- `openspec/changes/introduce-deadline-scheduler/tasks.md`

## Protected Unrelated Dirty Paths

The following dirty paths were present before this checkpoint and were not edited or staged by this apply group:

- `docs/agent-workflow.md`
- `openspec/changes/harden-add-initiate-automation-control/design.md`
- `openspec/changes/harden-add-initiate-automation-control/proposal.md`
- `openspec/changes/harden-add-initiate-automation-control/tasks.md`
- `openspec/changes/redesign-study-intake-planning/iteration-records/round-16-split-readiness-review.md`
- `openspec/changes/redesign-study-intake-planning/pre-split-readiness-audit.md`
- `openspec/changes/redesign-study-intake-planning/split-decision.md`
- `openspec/changes/redesign-study-intake-planning/tasks.md`

## Review

- Spec compliance: Passed. The scheduler dry-run examples now demonstrate the exact capacity math and option constraints described in design/spec.
- Code quality: Passed. The new fields are computed once from existing scheduler facts, have safe defaults, and do not mutate inputs or create downstream side effects.
- Residual risk: None for this change's backend scheduler scope. Downstream UI still needs to prove the review payload is rendered and confirmed correctly.

## Next

Next checkpoint: introduce-deadline-scheduler:apply:cross-change-contract-to-redesign-add-initiate-ui
