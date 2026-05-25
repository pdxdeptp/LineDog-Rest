# Round 21 Review: Estimate Normalization Deepening

## Reviewer Lens

Check whether the Plan Compiler has enough deterministic estimate rules to avoid scheduling from raw LLM guesses.

## Issue Found

P1: The mother design said estimates should use source facts, archetype defaults, LLM suggestions, clamps, and confidence, but did not define the source priority, default estimate table, outlier rules, or when rough estimates make a draft low-calibration.

## Modification Made

- Added estimate source priority to `design.md`.
- Added a v1 default estimate table by work type.
- Added concrete source-fact defaults for videos/courses, problem lists, and repo/module counts.
- Added clamp and validation rules for missing, tiny, oversized, and outlier estimates.
- Added confidence rules and a low-calibration threshold for rough essential work.
- Added spec and task coverage for estimate normalization tests.

## Result

The mother design now gives implementation a deterministic estimate normalization model before scheduling.
