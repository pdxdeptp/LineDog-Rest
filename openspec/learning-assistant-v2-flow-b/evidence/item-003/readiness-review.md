# ITEM-003 Readiness Review

## OpenSpec Validation

- `openspec validate introduce-study-plan-adjustment --strict`: PASS
- `openspec status --change introduce-study-plan-adjustment --json`: proposal, design, specs, and tasks are complete.
- `openspec instructions apply --change introduce-study-plan-adjustment --json`: 37 tasks, 0 complete, state `ready`.

## Affected Specs

- New spec id: `study-plan-adjustment`
- Existing v1 specs are not modified in this change.
- Completed but unarchived v2 context:
  - `introduce-study-plan-foundation` / `study-plan`
  - `introduce-study-views` / `study-views`

## Scope Review

- PASS with caution.
- Scope is large, but internally coherent: rollover, task move, add/delete, deadline editing, rest days, red facts, and dialogue preview all share the same active-plan adjustment invariant.
- D26/D27 rest days are included because the automation scope explicitly says D20-D28, even though the item queue originally emphasized US-8~11/15/16.
- Smart mode is explicitly excluded and remains ITEM-004.

## Dependency Review

- PASS.
- ITEM-001 provides confirmed study project/task facts.
- ITEM-002 provides Today, Project Overview, Calendar, task completion, and completed history surfaces.
- ITEM-003 can extend those payloads and controls without changing v1 specs.

## Safety Review

- PASS for proposal stage.
- No implementation code was written in this round.
- Before `opsx:apply`, create a checkpoint commit in the current checkout if no unrelated user changes are present.
- Worktree remains forbidden.

## Implementation Strategy Recommendation

Sequential backend-first TDD is recommended because tasks share database schema and helper functions.

Suggested implementation order:

1. Schema/red-state helpers.
2. Rollover and rolled badge facts.
3. Manual move and deadline edit.
4. Add/delete task.
5. Rest days and D27 cascade.
6. Dialogue preview/apply.
7. Swift API/ViewModel/UI.
8. App Use verification.

Parallel subagents should be avoided until schema and backend contract stabilize because most tasks touch overlapping DB/query/router files.

## Decision

Ready for `opsx:apply` after a checkpoint commit.
