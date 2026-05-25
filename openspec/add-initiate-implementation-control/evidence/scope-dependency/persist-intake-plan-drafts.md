# Scope Dependency Check: persist-intake-plan-drafts

## Timestamp

2026-05-25T06:24:10Z

## Change

`persist-intake-plan-drafts`

## Current Change Artifacts Read

- `openspec/changes/persist-intake-plan-drafts/proposal.md`
- `openspec/changes/persist-intake-plan-drafts/design.md`
- `openspec/changes/persist-intake-plan-drafts/tasks.md`
- `openspec/changes/persist-intake-plan-drafts/specs/learning-data-layer/spec.md`
- `openspec/changes/persist-intake-plan-drafts/specs/study-intake-planning/spec.md`
- `openspec/changes/persist-intake-plan-drafts/review-records/product-deepen-round-1.md`
- `openspec/changes/persist-intake-plan-drafts/review-records/product-deepen-round-2.md`
- `openspec/changes/persist-intake-plan-drafts/review-records/product-deepen-round-3.md`

## Upstream Change Artifacts Read

- `openspec/changes/introduce-study-intake-router/proposal.md`
- `openspec/changes/introduce-study-intake-router/design.md`
- `openspec/changes/introduce-study-intake-router/tasks.md`
- `openspec/changes/introduce-study-intake-router/specs/study-intake-planning/spec.md`
- `openspec/changes/introduce-study-intake-router/specs/material-ingestion/spec.md`
- `openspec/changes/introduce-study-intake-router/specs/learning-data-layer/spec.md`
- `openspec/add-initiate-implementation-control/evidence/cross-change-contracts/introduce-study-intake-router-to-persist-intake-plan-drafts.md`

## Downstream Change Artifacts Read

- `openspec/changes/introduce-plan-compiler/proposal.md`
- `openspec/changes/introduce-plan-compiler/design.md`
- `openspec/changes/introduce-plan-compiler/tasks.md`
- `openspec/changes/introduce-plan-compiler/specs/study-intake-planning/spec.md`
- `openspec/changes/introduce-deadline-scheduler/design.md`
- `openspec/changes/introduce-deadline-scheduler/tasks.md`

## Product Deepen Scope Record Check

All three product-deepen records contain explicit scope decisions:

- Round 1 records in-scope draft headers, lifecycle status, assumptions/provenance, snapshot versions, activation guard/event, fallback progress, and capacity defaults.
- Round 2 records in-scope migration compatibility, storage helper entry points, allowed lifecycle transitions, and invalid-transition rejection.
- Round 3 records in-scope draft kind, target plan persistence, existing-plan activation semantics, duplicate activation safety, and post-activation discard rejection.

Each round also records out-of-scope responsibilities, deferred upstream dependencies, and downstream contracts preserved. No record requires this change to implement intake routing, plan generation, scheduling, UI, or post-activation adjustment logic.

## In-Scope Responsibilities

- Persist draft plan state separately from active plan/task state.
- Link draft headers to router-created intake items.
- Persist draft lifecycle status, draft schema version, draft version, latest-version marker, and snapshot semantics.
- Persist planning assumptions, user-edited/accepted flags, provenance, calibration, source roles, and package shells for blocked/review states.
- Persist draft kind and target plan linkage for `new_plan`, existing-plan phase, and existing-plan scheduled-work handoffs.
- Provide data-layer entry points for create/load draft shell, save package shell, versioned edits, metadata updates, latest fetch, discard, activation, and fallback progress.
- Migrate or extend existing `study_project_drafts` and `study_project_draft_tasks` storage idempotently without touching active work.
- Guard activation with latest-version checks, activation-ready payload checks, target-plan checks, transaction rollback, activation events, duplicate activation safety, and post-activation discard rejection.
- Persist fallback-only completion separately from full task completion.
- Normalize missing capacity defaults to 60 minutes.

## Out-of-Scope Responsibilities

- Intake role routing, one-question routing clarification, GitHub/source preview, and non-plan storage.
- LLM phase generation, task generation, archetype selection, target-depth semantics, estimate normalization, compiler trace, or compiler repair loops.
- Deterministic date placement, capacity budgeting, buffer reservation, continuation-session splitting, risk reports, and infeasibility option effects.
- Add / Initiate UI, draft review screens, confirmation controls, and user-facing recovery surfaces.
- Smart-mode, rollover, adjustment behavior, or automatic movement of existing active tasks after activation.

## Required Upstream Contracts

Satisfied by `introduce-study-intake-router`:

- Durable `intakeItemId` and `clientRequestId`.
- Confirmed roles: `new_plan`, `attach_to_existing_plan`, `reference_material`, `later_resource`, and `immediate_one_off`.
- Attachment modes: `material_only`, `draft_phase`, and `scheduled_work`.
- Optional `existingPlanId` for existing-plan attachments.
- Separate canonical GitHub repo role from intake role.
- Handoff state `awaiting_anchor_review` for `new_plan`, `draft_phase`, and `scheduled_work`.
- `createsActiveTasks=false` invariant before draft activation.

No upstream blocker remains for draft persistence. The existing cross-change contract from router to draft persistence passed at 2026-05-25T06:00:40Z.

## Downstream Contracts Preserved

For `introduce-plan-compiler`, this change preserves:

- stable draft id, intake id, draft version, schema version, status, assumption/provenance fields, calibration, and package-shell persistence;
- storage helpers so compiler output does not manipulate tables ad hoc;
- blocked/review status support for `needs_input`, `compile_failed`, `infeasible_review`, and `draft_review`;
- no ownership over compiler archetype selection, phase/task generation, LLM schemas, estimate normalization, or compiler trace.

For `introduce-deadline-scheduler`, this change preserves:

- storable schedule slices and activation-ready data fields;
- activation rejection when schedule-ready data is missing;
- no ownership over final date placement, buffer rules, capacity placement, risk reports, or infeasibility option effects.

For `redesign-add-initiate-ui`, this change preserves persisted status/error facts and activation/discard outcomes without implementing UI.

## Deferred Dependencies

- Plan compilation remains deferred to `introduce-plan-compiler`.
- Deterministic scheduling remains deferred to `introduce-deadline-scheduler`.
- Add / Initiate draft review, confirmation, and adjustment UI remain deferred to `redesign-add-initiate-ui`.
- Active-plan adjustment after activation remains outside the Add / Initiate persistence boundary.

## Scope Decision

KEEP CURRENT SCOPE.

The current change is coherent and independently implementable as the draft persistence/data-layer boundary. It is broad but not mixed: all included tasks serve durable draft state, versioning, activation safety, fallback progress, and compatibility. The change should proceed to apply planning next.

## Validation Commands And Results

- `openspec validate persist-intake-plan-drafts --strict`: passed.
- `openspec validate introduce-plan-compiler --strict`: passed.
- `openspec status --change persist-intake-plan-drafts`: 4/4 artifacts complete.
- `rg -n '^## Scope Decisions|^### In Scope|^### Out Of Scope|^### Deferred Upstream Dependencies|^### Downstream Contracts Preserved' openspec/changes/persist-intake-plan-drafts/review-records/product-deepen-round-*.md`: confirmed all three records contain required scope decision sections.

## Result

Passed. `persist-intake-plan-drafts` has not absorbed router, compiler, scheduler, UI, or adjustment responsibilities. Upstream contracts are satisfied, downstream contracts are named without premature implementation, and all three product-deepen records include explicit scope decisions.

## Next Checkpoint

`persist-intake-plan-drafts:apply`
