# Round 09 Review: Real-Context Dry Runs

## Reviewer Lens

The plan compiler design must work on the user's actual planning objects, not only abstract examples.

## Issues Found

1. The previous compiler section did not walk through AgentGuide, easyagent, LeetCode, interview prep, or resume packaging.
2. Without dry runs, implementation could accidentally optimize for course-like sources and fail on recurring practice or project packaging.
3. Acceptance tests needed concrete outputs that distinguish good tasks from vague tasks.

## Modifications Made

- Added `Real-Context Dry Runs` to `design.md`.
- Added `Compiler Dry-Run Acceptance Examples` to `study-intake-planning/spec.md`.
- Added test task `6.7` for dry-run examples.

## Result

The compiler is now anchored to the user's real targets: agent repos, rebuild work, LeetCode cadence, interview prep, and resume/project packaging.
