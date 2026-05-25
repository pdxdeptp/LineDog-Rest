# Round 15 Review: Existing Plan, Fallback, And UX Recovery

## Reviewer Lens

The high-risk UX paths are attaching work to existing plans, completing only fallback work, and recovering from long-running or failed async operations.

## Issues Found

1. `existing_plan_phase` did not distinguish material-only attachment from draft phase or scheduled work.
2. Low-energy fallback completion did not specify persisted state and how follow-up stays visible.
3. Async progress and retry paths were not specified for preview/generation/validation/scheduling/activation failures.

## Modifications Made

- Added `Existing Plan Attachment Semantics` to `design.md`.
- Added `Low-Energy Fallback Completion Semantics`.
- Added `Async Feedback, Retry, And Recovery`.
- Updated `assistant-panel-ui`, `learning-data-layer`, and `study-intake-planning` specs accordingly.

## Result

The design now covers the messy but likely paths where users attach to active projects, have low energy, or hit LLM/source/scheduler failures.
