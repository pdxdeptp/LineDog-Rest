# Round 22 Review: Scope And Depth Reduction Rules

## Reviewer Lens

Check whether infeasibility fixes can be implemented without letting the system silently delete important work.

## Issue Found

P1: `reduce_scope` and `lower_depth` had deterministic option ids, but the design did not define what work can be removed, what evidence must remain, or when a reduction is not available. This could lead to AI-flavored arbitrary task deletion.

## Modification Made

- Added phase/task classification: essential, optional, stretch, and support-only.
- Defined the removal order for `reduce_scope`.
- Defined adjacent lower-depth transitions and when lowering depth requires changing target output.
- Required before/after review facts: minutes changed, tasks changed, evidence lost, target output/depth impact, and new risk state.
- Added spec and task coverage for auditable reduction tests.

## Result

The mother design now treats scope/depth reduction as a constrained recomputation with visible tradeoffs, not as silent task pruning.
