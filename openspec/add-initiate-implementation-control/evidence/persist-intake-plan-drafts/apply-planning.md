# Apply Planning: persist-intake-plan-drafts

## Decision

GO. The scope dependency check passed, all OpenSpec artifacts are complete, and the change can be applied as a backend/data-layer persistence slice without absorbing compiler, scheduler, UI, or adjustment behavior.

## Mechanical Check

- `openspec validate persist-intake-plan-drafts --strict`: pass.
- `openspec status --change persist-intake-plan-drafts --json`: ready; proposal, design, specs, and tasks are complete.
- `openspec instructions apply --change persist-intake-plan-drafts --json`: apply context and 35 pending tasks are available.
- Scope dependency prerequisite: pass; `changes[1].scopeDependencyCheckCompleted=true`.
- Workspace: unrelated dirty files are protected and must not be edited or staged by this change.

## Blockers

No blockers.

## Strong Recommendations

- Keep this apply backend/data-layer only. Do not build Add / Initiate UI or Plan Compiler generation in this change.
- Treat existing `study_project_drafts` and `study_project_draft_tasks` as legacy storage that must be extended or wrapped idempotently, not destructively replaced.
- Keep activation as a guarded transaction over activation-ready draft data. It must not generate task structure or assign dates.
- Keep existing-plan target semantics explicit: `new_plan` creates a new active resource, while existing-plan phase/scheduled-work appends under the recorded target plan.
- Preserve Today exclusion until activation, and preserve active rows after post-activation discard rejection.

## Test And Acceptance Gaps

- Blocking: none.
- Strongly recommended: TDD must cover legacy migration/idempotency, draft/active separation, versioning, stale activation, missing schedule rejection, transaction rollback, existing-plan activation target, duplicate activation, discard-after-activation, fallback-only progress, and 60-minute capacity defaults.
- Strongly recommended: keep legacy `/api/study-plan/start` / clarification / confirm tests passing while the data contract is expanded.

## Dispatch Recheck

Shared write targets:

- `assistant_backend/src/db/schema.py`
- `assistant_backend/src/db/init.py`
- `assistant_backend/src/study_plan/lifecycle.py`
- `assistant_backend/src/routers/study_plan.py`
- `assistant_backend/tests/test_study_plan_lifecycle.py`
- `assistant_backend/tests/test_study_plan_router.py`
- `assistant_backend/tests/test_integration.py`

Parallelization decision: must run sequentially for this automation. Schema migration, draft entry points, activation, fallback progress, and legacy router compatibility share tables, helper functions, and lifecycle tests.

Ownership rule:

- The schema/migration group owns table/column compatibility and default-capacity regression.
- The draft repository/versioning group owns assumptions, package shells, draft kinds, target plan linkage, and version semantics.
- The activation group owns active-row creation, activation events, stale/missing schedule checks, existing-plan activation, duplicate activation, invalid transitions, and discard guards.
- The fallback group owns fallback-only task progress and final compatibility verification.

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

Run `openspec-apply-change persist-intake-plan-drafts`, starting with the `draft-schema-migration-and-defaults` task group from `apply-task-groups.json`.
