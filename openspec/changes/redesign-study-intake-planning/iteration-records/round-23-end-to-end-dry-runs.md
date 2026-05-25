# Round 23 Review: End-To-End Dry Runs

## Reviewer Lens

Check whether real-context examples exercise the full planning pipeline with actual capacity math, not only example task wording.

## Issue Found

P1: The mother design included AgentGuide, easyagent, LeetCode, interview prep, and resume packaging examples, but did not include end-to-end dry runs with deadline, capacity, normalized minutes, buffer, schedule, and infeasibility options.

## Modification Made

- Added a feasible resume/project packaging dry run with Day 1-7 schedule, 285 minutes of essential work, 300 minutes of execution capacity, and one buffer day.
- Added an infeasible easyagent rebuild dry run with 525 minutes of essential work, 300 minutes of execution capacity, 225-minute capacity gap, hard-deadline option guardrails, and unavailable standalone `reduce_scope`.
- Added spec and task coverage for capacity-math dry-run tests.

## Result

The mother design now has concrete acceptance probes that test whether the compiler actually produces scheduleable daily work and honest infeasibility output.
