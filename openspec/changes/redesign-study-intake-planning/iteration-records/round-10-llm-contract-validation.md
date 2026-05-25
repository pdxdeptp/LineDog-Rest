# Round 10 Review: LLM Contract And Validation

## Reviewer Lens

LLM usage is acceptable only if the model has a narrow job, structured output, and deterministic validation. Otherwise the plan compiler becomes another one-shot planner.

## Issues Found

1. The previous text said "LLM proposes phases/tasks" but did not define the expected output shape.
2. It did not explicitly reject LLM-generated dates.
3. Repair behavior needed a bounded failure path.

## Modifications Made

- Added `Structured LLM Contracts` to `design.md` with phase and task JSON shapes.
- Added machine-readable validator error examples and bounded repair rules.
- Added `Structured LLM Output Validation` to `study-intake-planning/spec.md`.
- Added test task `6.6` for schema validation, forbidden dates, and bounded repair.

## Result

The LLM is now constrained to generating structured phase/task candidates. It does not own scheduling, and invalid output cannot silently become a confident plan.
