# Product Deepen Round 2: Migration And Entry Point Contracts

## Metadata

- Change: `persist-intake-plan-drafts`
- Round: 2
- Timestamp: 2026-05-25T06:10:40Z
- Skill: `opsx-product-deepen`

## Change Understanding

Round 1 made the logical draft storage model concrete. Round 2 reviewed whether an implementation worker could safely apply it in the existing codebase, which already contains legacy `study_project_drafts` and `study_project_draft_tasks` tables.

The main risk was not product scope expansion. It was implementation ambiguity: whether to alter legacy tables, replace them, write ad hoc queries, or accidentally treat migration as permission to touch active work.

## Adjacent Changes Read

Upstream: `introduce-study-intake-router`

- Provides durable intake items and `awaiting_anchor_review`.
- Does not expose draft query helpers or draft candidates.

Downstream: `introduce-plan-compiler`

- Needs stable storage entry points for draft package shells.
- Should not write tables ad hoc or decide migration mechanics.

## Experience Loops Reviewed

### Startup / Migration

- Entry: backend initializes with or without legacy draft tables.
- Success: missing draft persistence fields or companion tables are added idempotently.
- Failure: migration must not alter active tasks or duplicate draft versions/events.
- Coverage after edits: improved.

### Downstream Draft Save

- Entry: compiler later stores `needs_input`, `compile_failed`, `infeasible_review`, or `draft_review` package.
- Success: persistence layer exposes a stable save/fetch helper.
- Failure: incomplete compiler packages can be stored without requiring schedule-ready tasks.
- Coverage after edits: improved.

### Lifecycle Transition

- Entry: draft moves between anchor review, compiling, review, activation, discard, or non-plan exit.
- Success: allowed transition persists.
- Failure: invalid transition leaves prior state and active work unchanged.
- Coverage after edits: improved.

## Deep Issues

### P0: Legacy Draft Storage Compatibility Was Undefined

- Problem: Existing code has `study_project_drafts` and `study_project_draft_tasks`; docs did not say how this change should treat them.
- Why it matters: Apply could destructively replace tables, ignore old rows, or silently miss required fields.
- Applied direction: Added migration compatibility contract: idempotent add/companion storage, preserve existing rows, map legacy `review`, unknown provenance for unrecoverable facts, no active-work mutation.
- Destination: `design.md`, `learning-data-layer/spec.md`, `tasks.md`.
- Scope impact: In-scope data-layer migration only.

### P0: Downstream Entry Points Were Missing

- Problem: The docs specified entities but not the storage operations downstream changes should call.
- Why it matters: Compiler/scheduler/UI workers could write directly to tables and bypass version/activation guards.
- Applied direction: Added required logical operations for create/load draft shell, save package shell, versioned edits, metadata updates, latest fetch, discard, activation, and fallback progress.
- Destination: `design.md`, `tasks.md`.
- Scope impact: In-scope persistence API/helper surface. Does not add UI or compiler implementation.

### P0: Lifecycle Transition Failure Behavior Was Under-Specified

- Problem: Status names existed, but invalid transitions and recovery visibility were not specified.
- Why it matters: A bad transition could activate stale/incomplete drafts or lose the prior state.
- Applied direction: Added allowed V1 transitions and invalid-transition scenarios that preserve prior state and active-task exclusion.
- Destination: `design.md`, `learning-data-layer/spec.md`, `study-intake-planning/spec.md`, `tasks.md`.
- Scope impact: In-scope state persistence and validation.

## Scope Decisions

### In Scope

- Idempotent legacy draft storage migration/compatibility.
- Stable storage helper/repository operations.
- Allowed lifecycle transitions and invalid-transition rejection.
- Migration tests and lifecycle transition tests.

### Out Of Scope

- Compiler package generation.
- Scheduler date placement.
- User-facing review/recovery UI.
- Router role selection changes.

### Deferred Upstream Dependencies

- None. Router handoff remains sufficient.

### Downstream Contracts Preserved

- Compiler can rely on storage helpers and package shell persistence, but still owns generated phases/tasks/estimates.
- Scheduler can rely on schedule slices being storable later, but still owns final placement.
- UI can rely on persisted status/error information, but still owns presentation.

## Files Updated

- `openspec/changes/persist-intake-plan-drafts/design.md`
- `openspec/changes/persist-intake-plan-drafts/specs/learning-data-layer/spec.md`
- `openspec/changes/persist-intake-plan-drafts/specs/study-intake-planning/spec.md`
- `openspec/changes/persist-intake-plan-drafts/tasks.md`

## Validation

- `openspec validate persist-intake-plan-drafts --strict`: valid.

## Result

Round 2 addressed migration, compatibility, data-layer entry point, and lifecycle transition ambiguity. Continue to Round 3 to challenge testability, recovery evidence, and scope boundaries before `scope_dependency_check`.
