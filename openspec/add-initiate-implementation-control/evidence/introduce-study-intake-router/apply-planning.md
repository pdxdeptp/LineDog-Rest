# Apply Planning: introduce-study-intake-router

## Decision

GO. The change is mechanically ready, the scope dependency check passed, and the implementation can be applied as a backend-only router/data/preview slice without absorbing draft persistence, plan compilation, scheduling, or UI work.

## Mechanical Check

- `openspec validate introduce-study-intake-router --strict`: pass.
- `openspec status --change introduce-study-intake-router --json`: ready; proposal, design, specs, and tasks are complete.
- `openspec instructions apply --change introduce-study-intake-router --json`: apply context and 21 pending tasks are available.
- Scope dependency prerequisite: pass; `changes[0].scopeDependencyCheckCompleted=true`.

## Blockers

No blockers.

## Strong Recommendations

- Keep this apply backend-only. Do not modify Swift Add / Initiate UI in this change; `redesign-add-initiate-ui` owns that surface.
- Implement Add / Initiate source preview as a separate preview path. Do not reuse the legacy confirmed ingestion path in a way that writes resources, units, or tasks during intake.
- Treat draft-plan candidates as absent unless a downstream draft-persistence surface exists. This router may attach to existing active plans, but it must not implement draft-plan discovery.

## Test And Acceptance Gaps

- Blocking: none.
- Strongly recommended: TDD must cover idempotent `clientRequestId`, all five machine roles, one-question ambiguity, GitHub preview success/failure/no-fabrication, existing-plan target selection, and Today exclusion.
- Strongly recommended: keep a regression assertion that legacy `/api/study-plan/start` still works separately from the new Add / Initiate router.

## Dispatch Recheck

Shared write targets:

- `assistant_backend/src/db/schema.py`
- `assistant_backend/src/main.py`
- `assistant_backend/tests/test_study_intake_router.py` or equivalent new router test file
- any new shared intake helper under `assistant_backend/src/study_plan/`

Parallelization decision: must run sequentially for this automation. Data schema, preview helpers, and router contracts touch shared tests and shared backend registration, so apply groups should be executed in dependency order.

Ownership rule:

- The data/idempotency group owns schema and persistence helpers.
- The preview group owns material/GitHub preview helpers and handler-model extensions.
- The router contract group owns API route registration, routing decisions, clarification, and existing-plan selection.

## Existing Code Feasibility Notes

- Current draft flow lives in `assistant_backend/src/routers/study_plan.py`, `assistant_backend/src/study_plan/lifecycle.py`, and `assistant_backend/src/study_plan/decomposition.py`.
- Current schema has active `resources`, `units`, `tasks`, and existing `study_project_drafts`; this change should add intake/non-plan state without inserting active rows.
- Current Today facts come from active `tasks` joined to active `resources`, so storing intake/non-plan records outside those tables preserves Today exclusion.
- Existing GitHub handling in `assistant_backend/src/handlers/github_handler.py` may fabricate fallback units for the legacy confirmed path; Add / Initiate preview must keep unknown structure unknown.

## Next Step

Run `opsx:apply introduce-study-intake-router`, starting with the `intake-data-and-idempotency` task group from `apply-task-groups.json`.
