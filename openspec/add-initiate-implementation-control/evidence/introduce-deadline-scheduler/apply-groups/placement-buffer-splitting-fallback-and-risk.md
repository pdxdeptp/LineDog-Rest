# Apply Group Evidence: placement-buffer-splitting-fallback-and-risk

- Automation: add-initiate-changes
- Change: introduce-deadline-scheduler
- Checkpoint: introduce-deadline-scheduler:apply:placement-buffer-splitting-fallback-and-risk
- Completed at: 2026-05-25T11:47:41Z
- Functional commit: 19293e38a7a8a5fb0c93101d6ef97f771a0bbd31

## Scope

Implemented tasks 1.6-1.10, 2.1-2.6, and 4.4-4.8 for deterministic placement, buffer reservation/erosion, load-shape distribution, dependency preservation, continuation-session splitting, fallback metadata, no active-task side effects, and risk-report facts.

## TDD Record

RED tests were added before implementation for:

- 80% planning budget and deterministic buffer reservation/erosion.
- Balanced, front-loaded, and light-start load shape tie-breakers.
- Essential-before-optional placement and dependency preservation.
- Out-of-order dependency readiness reordering.
- Continuation-session parent identity, date distribution, and visible continuation output.
- Split estimate conservation and infeasible mismatch handling.
- Trial buffer erosion rollback when a split task cannot fit.
- Fallback metadata staying review-only and copied from compiler input.
- Risk report capacity gap, optional unscheduled minutes, rough estimates, existing-load conflicts, and overloaded dates.
- Accepted overload on explicitly selected dates, including zero usable capacity caused by existing active load.

Initial RED failures confirmed missing implementation paths for planning budgets, load shapes, continuation sessions, split conservation, buffer gap math, dependency reordering, fallback aliasing, overload facts, and zero-usable overload acceptance.

## Implementation Summary

- Added default `planning_budget_min = floor(usable_capacity_min * 0.8)`.
- Added deterministic buffer day reservation and visible `reserved_buffer`.
- Added buffer erosion status blocking until `accept_buffer_risk` or `buffer_erosion` is accepted.
- Added balanced, front-loaded, and light-start placement with deterministic tie-breakers.
- Added dependency-aware ordering so ready dependencies can be placed before dependents even when compiler order is inverted.
- Added continuation sessions only for approved split points or explicit multi-session boundaries, with parent identity, sequence, session estimate, source refs, completion criteria, and visible sub-output.
- Rejected split definitions whose session minutes do not conserve the parent estimate.
- Added accepted overload placement for explicit dates, with `overloaded_dates` remaining visible.
- Added risk facts for essential capacity gap before unaccepted buffer/overload, optional unscheduled minutes, expected-late tasks, buffer erosion, rough estimate confidence, and existing-load conflicts.
- Deep-copied fallback metadata so review payload edits cannot mutate the compiler package.
- Preserved scheduler purity: no active task writes, no Today actions, no deadline extension, no depth lowering, no compiler-package mutation.

## Review Record

- Spec compliance review first found P1 issues in split-session capacity simulation, split estimate conservation, and buffer capacity-gap math.
- Code quality review independently found the same split risks plus dependency-order and buffer-gap concerns.
- Fixes added regression tests and implementation updates for those findings.
- Follow-up reviews found P1 issues for dependency reordering and overload facts; fixes added tests for dependency inversion, overload facts, buffer rollback, fallback copy, and numeric continuation notes.
- Final spec-compliance review approved with no P0/P1/P2 findings.
- Final code-quality review found one P1 zero-usable overload edge case; a RED test reproduced it, the implementation was fixed, and a final code-quality review approved with no P0/P1/P2 findings.

## Verification

- `cd assistant_backend && uv run pytest tests/test_study_plan_scheduling.py -k 'buffer or load_shape or continuation or fallback or risk or optional or dependency or active_task or overloaded or existing_load_consumes_all_usable_capacity'`: 13 passed.
- `cd assistant_backend && uv run pytest tests/test_study_plan_scheduling.py`: 27 passed.
- `openspec validate introduce-deadline-scheduler --strict`: valid.
- `openspec instructions apply --change introduce-deadline-scheduler --json`: 25/36 complete, 11 remaining.
- `git diff --check -- assistant_backend/src/study_plan/scheduling.py assistant_backend/tests/test_study_plan_scheduling.py`: no whitespace errors.

## Artifact Hashes

- `assistant_backend/src/study_plan/scheduling.py`: fb965d9607555c37e6fe36344cfbc5fc864882527c5435fe9845f3a6ac109529
- `assistant_backend/tests/test_study_plan_scheduling.py`: f79e2d667af812b3726f8241c9ea572b885f6ab61b8568fcc21e757d679a1bd1
- `openspec/changes/introduce-deadline-scheduler/tasks.md`: ea7eeabff857d0ccd24dc87f5548cd5e67597a8a67213dd3ecf46d242346e4fc

## Next

Next checkpoint: introduce-deadline-scheduler:apply:infeasibility-options-and-recompute-effects.
