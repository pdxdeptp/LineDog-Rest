# Round 08 Review: Plan Compiler Deepening

## Reviewer Lens

The previous design fixed the product framing, but implementation would still have to guess how a goal becomes phases, task candidates, estimates, and scheduled daily work.

## Issues Found

1. `Plan Draft Compiler` was described at a principle level but not as an implementable pipeline.
2. LLM vs deterministic responsibility was not explicit enough.
3. Task quality gates were missing, so vague tasks such as "learn LangGraph" could slip through.
4. Scheduling behavior did not specify the data consumed or the exact kind of infeasibility output expected.

## Modifications Made

- Added a full `Plan Compiler Pipeline` section to `design.md`.
- Defined compiler inputs, outputs, staged processing, archetype-specific decomposition rules, task quality gates, and deterministic scheduling policy.
- Added spec requirements for compiler contract, phase/milestone decomposition, executable task candidates, task quality gates, estimate normalization, deterministic draft scheduling, and infeasibility options.
- Expanded `tasks.md` Plan Draft Compiler work from 5 broad tasks to 10 smaller implementation tasks.

## Result

The design now treats plan generation as a compiler pipeline: LLM creates structured phase/task candidates, deterministic validators normalize and reject weak tasks, and a deterministic scheduler assigns dates and reports fit/risk.
