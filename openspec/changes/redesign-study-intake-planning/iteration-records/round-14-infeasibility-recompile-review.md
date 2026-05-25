# Round 14 Review: Infeasibility And Recompile Rules

## Reviewer Lens

An infeasible plan is expected, not exceptional. The design needs deterministic option effects so the system can explain what changes and rerun only the necessary parts.

## Issues Found

1. Infeasibility options were listed but did not define their effects.
2. Draft edits did not say whether to rerun LLM task generation or only deterministic scheduling.
3. Scheduler defaults were still too loose for v1 implementation.

## Modifications Made

- Added v1 scheduler defaults to `design.md`.
- Added `Draft Editing And Recompile Rules` and `Infeasibility Option Effects`.
- Added spec scenarios for deterministic infeasibility effects and draft version creation.
- Added tasks for edit classification and infeasibility option effects.

## Result

The plan compiler can now handle "does not fit" as a reviewable state with deterministic next steps.
