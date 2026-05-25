# Apply Planning: introduce-deadline-scheduler

## Decision

GO. The scope dependency check passed, all OpenSpec artifacts are complete, and this change can enter implementation as a deterministic backend scheduler slice.

Apply must not absorb compiler task generation, draft persistence internals, Add / Initiate UI controls, activation, Today writes, existing active-task mutation, or runtime fallback adjustment.

## Mechanical Check

- `openspec validate introduce-deadline-scheduler --strict`: pass.
- `openspec status --change introduce-deadline-scheduler --json`: ready; proposal, design, specs, and tasks are complete.
- `openspec instructions apply --change introduce-deadline-scheduler --json`: apply context available with 36 pending tasks.
- Scope dependency prerequisite: pass; `changes[3].scopeDependencyCheckCompleted=true`.
- Workspace: unrelated dirty files are protected and must not be edited or staged by this change.

## Existing Implementation Context

The backend already has a legacy deterministic scheduler surface:

- `assistant_backend/src/study_plan/scheduling.py`
- `assistant_backend/tests/test_study_plan_scheduling.py`
- `assistant_backend/src/study_plan/__init__.py`

The existing `plan_initial_draft_schedule` helper schedules simple tasks and has older tests. Apply should evolve or wrap this module through TDD while preserving any still-valid behavior only when it does not contradict the new OpenSpec contract.

## Blockers

No blockers.

## Strong Recommendations

- Implement the new scheduler as pure deterministic functions and serializable review dictionaries so tests do not need network, database, or UI.
- Keep scheduler statuses separate from compiler statuses: scheduler may return `needs_input`, `draft_review`, or `infeasible_review`, while compiler `needs_input`/`compile_failed` pass through unscheduled.
- Preserve task ids and parent task ids through continuation sessions.
- Make all defaulted anchors visible in assumptions or trace.
- Treat option effects as recomputation/storage/handoff results, never activation.
- Keep hard-deadline behavior impossible to bypass with `accept_late_finish`.

## Dispatch Recheck

Shared write targets:

- `assistant_backend/src/study_plan/scheduling.py`
- `assistant_backend/src/study_plan/__init__.py`
- `assistant_backend/tests/test_study_plan_scheduling.py`
- `openspec/changes/introduce-deadline-scheduler/tasks.md`

Parallelization decision: must run sequentially for this automation. The groups share the scheduler module and scheduler test file, and later option/dry-run behavior depends on the core review payload, capacity model, and placement logic.

Ownership rule:

- The contract/preflight group owns input gates, review output shapes, safe defaults, date windows, basic capacity, and scheduler status derivation.
- The placement/risk group owns buffer reservation, buffer erosion, load-shape placement, dependency preservation, continuation sessions, fallback metadata, and risk facts.
- The option-effects group owns canonical option mapping and deterministic recomputation/storage/compiler-handoff results.
- The final dry-run group owns real-context dry-run fixtures, full scheduler verification, strict OpenSpec validation, and marking tasks complete.

## Protected Unrelated Dirty Paths

- `docs/agent-workflow.md`
- `openspec/changes/harden-add-initiate-automation-control/design.md`
- `openspec/changes/harden-add-initiate-automation-control/proposal.md`
- `openspec/changes/harden-add-initiate-automation-control/tasks.md`
- `openspec/changes/redesign-study-intake-planning/iteration-records/round-16-split-readiness-review.md`
- `openspec/changes/redesign-study-intake-planning/pre-split-readiness-audit.md`
- `openspec/changes/redesign-study-intake-planning/split-decision.md`
- `openspec/changes/redesign-study-intake-planning/tasks.md`

## Next Step

Run `openspec-apply-change introduce-deadline-scheduler`, starting with the `scheduler-contract-preflight-and-capacity` task group from `apply-task-groups.json`.

