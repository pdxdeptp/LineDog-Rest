# ITEM-004 Readiness Review

## OpenSpec Validation

- `openspec validate introduce-study-smart-mode --strict`: PASS
- `openspec status --change introduce-study-smart-mode --json`: proposal, design, specs, and tasks are complete.
- `openspec instructions apply --change introduce-study-smart-mode --json`: 28 tasks, 1 complete before readiness updates, state `ready`.

## Affected Specs

- New spec id: `study-smart-mode`
- Existing v1 specs are not modified in this change.
- Completed but unarchived v2 context:
  - `introduce-study-plan-foundation` / `study-plan`
  - `introduce-study-views` / `study-views`
  - `introduce-study-plan-adjustment` / `study-plan-adjustment`

## Scope Review

- PASS with caution.
- Scope is coherent because all requirements share one invariant: smart mode is an opt-in proposal layer over existing v2 manual operations.
- Scope is larger than a narrow polish pass because it crosses backend settings, factual snapshot/proposal services, Swift API/ViewModel, and UI surfaces.
- Full-auto smart mode, v1 spec retirement, new credentials, and broad conversational planner behavior are explicitly out of scope.

## Dependency Review

- PASS.
- ITEM-001 provides active study-project/task facts.
- ITEM-002 provides Today, Project Overview, Calendar, completed history, and factual dashboard refresh behavior.
- ITEM-003 provides rollover, red-state facts, manual adjustment primitives, bounded dialogue preview/apply, and default-mode silence.
- ITEM-004 can build on those facts without modifying old v1 specs.

## V1 Isolation Review

- PASS with a hard implementation guard.
- The existing v1 `daily-morning-agent` MUST NOT be called from smart-mode briefing or proposal routes because it may run weekly review, reschedule tasks, and calibrate speed factors.
- The existing v1 `conversational-planner` MUST NOT be used for smart proposal generation or apply because it is broad LLM agent behavior tied to old chat state.
- Swift default dashboard refresh already uses v2 study views; implementation should preserve and test this.

## Split / Parallelism Review

- PASS for a single OpenSpec change, but implementation should be mostly sequential until the backend contract stabilizes.
- Backend setting and fact snapshot should land before proposal generation.
- Proposal apply should land before Swift apply UI.
- Swift API, ViewModel, and UI tasks touch overlapping files and should not be parallelized aggressively.

## Safety Review

- PASS for proposal stage.
- No implementation code was written in this round.
- Before `opsx:apply`, create a checkpoint commit in the current checkout if no unrelated user changes are present.
- Worktree remains forbidden.

## Decision

Ready for `opsx:apply` after checkpoint commit. The first implementation slice should start with tasks 2.1 and 2.2: backend smart-mode setting tests and minimal routes/storage.
