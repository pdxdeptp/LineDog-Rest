# Apply Group Evidence: infeasibility-options-and-recompute-effects

- Automation: add-initiate-changes
- Change: introduce-deadline-scheduler
- Checkpoint: introduce-deadline-scheduler:apply:infeasibility-options-and-recompute-effects
- Completed at: 2026-05-25T12:17:11Z
- Result: completed
- Implementation commit: 38242e79df7c23f6d545c5635904f46f1ee9c6e3

## Scope

Implemented scheduler option mapping and option-effect handling for tasks 3.1-3.7 and 4.9-4.11.

In scope:

- Fact-to-option mapping for capacity gap, buffer erosion, overloaded dates, expected late work, and low calibration.
- Deterministic option effects that return draft review recomputation, storage state, or compiler recomputation handoff.
- `accept_crunch` up to usable capacity, distinct from `accept_overload` over usable capacity.
- Reduce-scope removal of optional/stretch tasks with before/after fit facts.
- Lower-depth and answer-one-question compiler handoffs.
- Hard-deadline guard excluding `accept_late_finish`.

Out of scope:

- Scheduler dry-run fixtures and final full-change verification remain in `scheduler-dry-runs-final-verification`.
- UI rendering of option cards remains downstream in `redesign-add-initiate-ui`.

## TDD Record

RED:

- Added tests for canonical infeasibility option mapping, hard deadline late-finish guard, option effects returning review/storage/recompute states, reduce-scope recomputation, lower-depth and answer-one-question handoffs, and crunch-versus-overload semantics.
- Initial targeted run failed as expected: 6 failed, 5 passed, 22 deselected.

GREEN:

- Added canonical option construction with multi-fact tracking.
- Added `apply_schedule_option` as the deterministic option-effect entry point.
- Added `accept_crunch` handling by raising selected dates to usable capacity without hiding overload semantics.
- Added reduce-scope, lower-depth, answer-one-question, storage, estimate edit, buffer-risk, overload, rebalance, rough-draft, and late-finish option effects.
- Marked tasks 3.1-3.7 and 4.9-4.11 complete.

REFACTOR:

- Kept option effects as pure review/storage/recompute results; no active tasks or Today actions are created.
- Preserved existing scheduler placement tests and existing public scheduling behavior.

## Verification

- `cd assistant_backend && uv run pytest tests/test_study_plan_scheduling.py -k 'option or recompute or crunch or overload or reduce_scope or lower_depth or hard_deadline or late_finish'`: 11 passed, 22 deselected.
- `cd assistant_backend && uv run pytest tests/test_study_plan_scheduling.py`: 33 passed.
- `openspec validate introduce-deadline-scheduler --strict`: valid.

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

- Spec compliance: Passed. The group implements the scheduler-owned option mapping/effects without moving activation or UI responsibilities into this change.
- Code quality: Passed. Option effects are deterministic and operate on copied package data; no user data is mutated in place.
- Residual risk: `apply_schedule_option` is intentionally minimal for first-version scheduler internals. Downstream UI and final dry-run evidence still need to verify how these option payloads are presented and consumed.

## Next

Next checkpoint: introduce-deadline-scheduler:apply:scheduler-dry-runs-final-verification
