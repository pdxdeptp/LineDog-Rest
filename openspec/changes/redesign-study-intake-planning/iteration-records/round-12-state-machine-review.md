# Round 12 Review: Lifecycle State Machine

## Reviewer Lens

Implementation workers need a shared async lifecycle. Without it, router, compiler, UI, persistence, and activation can each invent different states.

## Issues Found

1. The flow diagram was linear and did not cover `needs_input`, `compile_failed`, `infeasible_review`, stale activation, or activation failure.
2. Cancellation behavior was only described in prose and did not distinguish pre-activation from post-activation.
3. UI progress and backend states were not aligned.

## Modifications Made

- Added `Lifecycle State Machine` to `design.md`.
- Added `Intake And Draft Lifecycle State Machine` requirement to `study-intake-planning/spec.md`.
- Added UI tasks and test tasks for state-machine coverage.

## Result

The mother design now has a shared lifecycle that all split implementation changes can reference.
