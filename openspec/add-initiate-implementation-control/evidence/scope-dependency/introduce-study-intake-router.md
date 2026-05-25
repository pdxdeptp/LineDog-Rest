# Scope Dependency Check: introduce-study-intake-router

## Timestamp

2026-05-25T04:22:26Z

## Change

`introduce-study-intake-router`

## Current Change Artifacts Read

- `openspec/changes/introduce-study-intake-router/proposal.md`
- `openspec/changes/introduce-study-intake-router/design.md`
- `openspec/changes/introduce-study-intake-router/tasks.md`
- `openspec/changes/introduce-study-intake-router/specs/study-intake-planning/spec.md`
- `openspec/changes/introduce-study-intake-router/specs/material-ingestion/spec.md`
- `openspec/changes/introduce-study-intake-router/specs/learning-data-layer/spec.md`
- `openspec/changes/introduce-study-intake-router/review-records/product-deepen-round-1.md`
- `openspec/changes/introduce-study-intake-router/review-records/product-deepen-round-2.md`
- `openspec/changes/introduce-study-intake-router/review-records/product-deepen-round-3.md`

## Upstream Change Artifacts Read

- None. This is the first Add / Initiate child change.

## Downstream Change Artifacts Read

- `openspec/changes/persist-intake-plan-drafts/proposal.md`
- `openspec/changes/persist-intake-plan-drafts/design.md`
- `openspec/changes/persist-intake-plan-drafts/tasks.md`
- `openspec/changes/persist-intake-plan-drafts/specs/learning-data-layer/spec.md`
- `openspec/changes/persist-intake-plan-drafts/specs/study-intake-planning/spec.md`

## Product Deepen Scope Record Check

All three product-deepen records now contain explicit scope decisions:

- Round 1 includes a scope decisions addendum added during this audit because Round 1 predated the scope-aware automation policy.
- Round 2 includes a scope decisions addendum added during this audit because Round 2 predated the scope-aware automation policy.
- Round 3 was already written as a scope-aware product deepen and includes the required scope decisions.

The addenda record the boundary already implied by the original records and do not change their product findings.

## In-Scope Responsibilities

- Create idempotent intake items using `clientRequestId`.
- Accept the bounded first-version input set.
- Generate route recommendations for `new_plan`, `attach_to_existing_plan`, `reference_material`, `later_resource`, and `immediate_one_off`.
- Return confidence, reason codes, next actions, and at most one routing clarification question.
- Keep intake machine role separate from GitHub/source canonical role.
- Use material and GitHub preview as routing signals without creating active resources, units, or tasks.
- Store non-plan outcomes and material-only attachments outside active scheduling.
- Preserve the no-active-task invariant for every router outcome.

## Out-of-Scope Responsibilities

- Persisting full `PlanDraft`, `DraftPhase`, `DraftTask`, or `ActivationEvent` state.
- Implementing draft-plan discovery or draft lifecycle queries.
- Generating phase/task candidates.
- Running deadline scheduling or assigning daily slices.
- Building the Add / Initiate review UI.
- Activating draft plans into active Today or Calendar tasks.
- Post-activation smart-mode, rollover, or adjustment behavior.

## Required Upstream Contracts

- None. The current change has no upstream Add / Initiate child change.

## Downstream Contracts Preserved

For `persist-intake-plan-drafts`, this router preserves:

- `intakeItemId`
- `clientRequestId`
- `confirmedRole`
- `attachmentMode`
- optional `existingPlanId`
- `canonicalRepoRole`
- `materialRole`
- `createsActiveTasks=false`

The router may return handoff states such as `awaiting_anchor_review`, but downstream draft persistence owns durable draft state, draft versions, activation events, fallback completion persistence, and the 60-minute capacity default.

## Deferred Dependencies

- Draft plan persistence and draft versioning are deferred to `persist-intake-plan-drafts`.
- Plan compilation is deferred to `introduce-plan-compiler`.
- Deadline scheduling is deferred to `introduce-deadline-scheduler`.
- Add / Initiate UI review and confirmation surfaces are deferred to `redesign-add-initiate-ui`.

## Validation Commands And Results

- `openspec validate introduce-study-intake-router --strict`: passed.
- `openspec validate persist-intake-plan-drafts --strict`: passed.
- `openspec status --change introduce-study-intake-router`: 4/4 artifacts complete.

## Result

Passed. `introduce-study-intake-router` has not absorbed downstream draft persistence, plan compilation, scheduling, or UI responsibilities. The current change names downstream contracts clearly enough for the next change while keeping implementation scope limited to routing and non-plan safety.

## Next Checkpoint

`introduce-study-intake-router:apply`
