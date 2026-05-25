# Cross-Change Contract: introduce-study-intake-router -> persist-intake-plan-drafts

## Timestamp

2026-05-25T06:00:40Z

## From Change

`introduce-study-intake-router`

## To Change

`persist-intake-plan-drafts`

## Specs Read

From `introduce-study-intake-router`:

- `openspec/changes/introduce-study-intake-router/specs/study-intake-planning/spec.md`
- `openspec/changes/introduce-study-intake-router/specs/learning-data-layer/spec.md`
- `openspec/changes/introduce-study-intake-router/specs/material-ingestion/spec.md`

To `persist-intake-plan-drafts`:

- `openspec/changes/persist-intake-plan-drafts/specs/study-intake-planning/spec.md`
- `openspec/changes/persist-intake-plan-drafts/specs/learning-data-layer/spec.md`

## Tasks Read

- `openspec/changes/introduce-study-intake-router/tasks.md`
- `openspec/changes/persist-intake-plan-drafts/tasks.md`

## Contract Surfaces Checked

### Handoff Payloads

Passed.

- Router exposes `POST /api/study-intake/route` and `POST /api/study-intake/confirm`.
- Route result includes `intakeItemId`, `recommendedRole`, `confidence`, `reasonCodes`, `nextAction`, and `createsActiveTasks=false`.
- Confirmation for plan-generating outcomes returns `nextAction=handoff_to_anchor_review` and `outcome=awaiting_anchor_review`.
- Confirmation for existing-plan `scheduled_work` / `draft_phase` returns `existingPlanId` and `attachmentMode`.
- Non-plan outcomes return stored non-plan or material-only attachment IDs and remain outside active scheduling.

### Persisted Entities

Passed.

- `study_intake_items` stores the intake anchor needed by draft persistence: request id, raw input, source type, recommended role, confidence, reason codes, next action, confirmation state, and calibration level.
- `study_intake_non_plan_items` stores reference/later/one-off non-plan outcomes outside active tasks.
- `study_intake_plan_attachments` stores material-only existing-plan attachments with target plan and attachment mode.
- Plan-generating confirmations update the intake item to `confirmation_state='awaiting_anchor_review'` without creating draft rows.

### Enum And State Contracts

Passed.

- Intake roles available to downstream: `new_plan`, `attach_to_existing_plan`, `reference_material`, `later_resource`, `immediate_one_off`.
- Attachment modes available to downstream: `material_only`, `draft_phase`, `scheduled_work`.
- Canonical GitHub repo roles are separate from intake roles and do not replace machine roles.
- Downstream draft persistence can treat `awaiting_anchor_review` as the durable pre-draft handoff state.

### Active-Task Boundary

Passed.

- Router guarantees `createsActiveTasks=false`.
- Add / Initiate preview does not write active resources, units, or tasks.
- Material-only attachment does not alter active schedules.
- `new_plan`, `draft_phase`, and `scheduled_work` are only handoff intents at this boundary.

### Downstream Responsibilities Preserved

Passed.

The router change intentionally did not implement:

- `PlanDraft`, `DraftPhase`, `DraftTask`, or `ActivationEvent` semantics.
- Draft schema/version increment rules.
- Planning assumption persistence.
- Stale draft activation guards.
- Plan Compiler data contracts.
- Deterministic scheduling.
- Add / Initiate UI.

These remain in scope for `persist-intake-plan-drafts` and later child changes.

## Validation Commands And Results

- `openspec validate introduce-study-intake-router --strict`: valid.
- `openspec validate persist-intake-plan-drafts --strict`: valid.
- `openspec instructions apply --change introduce-study-intake-router --json`: 21/21 tasks complete.
- `openspec status --change persist-intake-plan-drafts --json`: proposal/design/specs/tasks artifacts present.

## Handoff Risks

- The current codebase already contains older `study_project_drafts` tables, but `persist-intake-plan-drafts` must still implement the new draft lifecycle contract explicitly: intake linkage, assumptions, schema version, draft version, stale activation rejection, activation events, and fallback completion semantics.
- `materialRole` remains optional in the router contract and is not required by `persist-intake-plan-drafts` tasks.
- Low-calibration routing and preview details are available through intake item fields/reason codes, but richer planning-assumption provenance remains downstream.

## Result

Passed. `introduce-study-intake-router` can be marked completed, and automation can advance to `persist-intake-plan-drafts:product_deepen_round_1`.

## Next Checkpoint

`persist-intake-plan-drafts:product_deepen_round_1`
