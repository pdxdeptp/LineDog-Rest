# Round 11 Review: Deterministic Scheduler

## Reviewer Lens

Deadline-driven planning depends on a scheduler that computes capacity and risk honestly instead of writing a plausible calendar.

## Issues Found

1. The scheduler policy described goals but not enough concrete data calculations.
2. Existing active load needed to be part of `usableCapacity`.
3. Optional work and load-shape behavior needed explicit placement rules.
4. Infeasibility options needed to map to concrete facts rather than generic suggestions.

## Modifications Made

- Added `Scheduler Algorithm` and `Infeasibility Decision Matrix` to `design.md`.
- Added scheduler scenarios for usable capacity, essential-before-optional placement, load shapes, and fact-mapped infeasibility choices.
- Added test task `6.8` for scheduler behavior.

## Result

The scheduler is now specified as a deterministic capacity/risk engine. It can return an infeasible draft honestly instead of hiding risk through silent changes.
