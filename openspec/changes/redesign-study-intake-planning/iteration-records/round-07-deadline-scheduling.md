# Round 07 Review: Deadline / Scheduling System

## Reviewer Lens

Deadline-driven planning is the core. The design must be precise enough that scheduling cannot quietly overfill days, consume all buffer, or pretend an impossible deadline is feasible.

## Issues Found

1. Deadline semantics needed to distinguish hard deadlines, soft deadlines, and assumed dates.
2. Buffer policy needed an explicit "buffer can be consumed only visibly" rule.
3. Infeasible plans needed deterministic user choices rather than hidden auto-repair.
4. Existing active-plan load needed to affect risk display even if the draft scheduler does not silently optimize around it.

## Modifications Made

- Added Decision 12 to `design.md` for deadline semantics and feasibility.
- Added deadline/capacity feasibility scenarios to `study-intake-planning`.
- Strengthened draft scheduling behavior to expose existing-load conflicts and buffer erosion.

## Result

The scheduling contract now makes the central promise testable: plans are deadline-driven, honest about capacity, and adjustable by the user rather than magically repaired.
