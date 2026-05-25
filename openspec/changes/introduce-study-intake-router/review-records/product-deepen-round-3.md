# Product Deepen Round 3

## Change Understanding

`introduce-study-intake-router` is the routing and non-plan safety slice. It should create idempotent intake items, preview sources, recommend roles, clarify one routing ambiguity, store non-plan outcomes, and prepare logical handoff to downstream draft planning without compiling, scheduling, or persisting full plan drafts.

This round focused on scope discipline against adjacent changes:

- upstream: none in the Add / Initiate child-change chain;
- downstream: `persist-intake-plan-drafts`.

## Scope Decisions

### In Scope

- Idempotent intake item creation using `clientRequestId`.
- Route result and confirmation contracts.
- Intake machine roles and confidence/reason codes.
- Source/material preview as a routing helper.
- Canonical GitHub/source roles as source metadata.
- Existing active-plan attachment intent and material-only storage.
- No-active-task invariant for all router outcomes.

### Out Of Scope

- Plan draft persistence.
- Draft-plan discovery/query implementation.
- Draft versioning and activation events.
- Phase/task generation.
- Deadline scheduling.
- Add / Initiate review UI.
- Post-activation adjustment/smart-mode behavior.

### Deferred Upstream Dependencies

- None. This is the first child change in the chain.

### Downstream Contracts Preserved

For `persist-intake-plan-drafts`, this change preserves:

- `intakeItemId`;
- `confirmedRole`;
- `attachmentMode`;
- `existingPlanId` when confirmed;
- `canonicalRepoRole`;
- `materialRole`;
- idempotent `clientRequestId`;
- no active task rows before downstream draft activation.

The router may name draft-plan surfaces as available downstream integration points, but it must not implement draft-plan persistence or discovery by itself.

## Experience Loops Reviewed

### Active Plan Attachment Without Draft Persistence

- Goal: support material or work intent for existing plans without pulling draft persistence into the router.
- Entry: submitted item appears related to an existing plan.
- Main path: use active plans already available; if target is missing or ambiguous, return target selection/clarification.
- Success: target and mode are confirmed before handoff.
- Failure: no target candidate returns storage/new-plan alternatives.
- Coverage after this round: complete enough for apply.

### Downstream Handoff

- Goal: give later child changes enough payload to continue without making router own draft lifecycle.
- Entry: confirmed `new_plan`, `draft_phase`, or `scheduled_work`.
- Main path: store intake item and confirmed routing facts.
- Success: downstream draft persistence/compiler can build from stable handoff fields.
- Coverage after this round: complete enough for apply.

## Deep Issues

### P1: Router text still implied draft-plan discovery

Problem: Some wording said the router could use active/draft plan titles and attach to active or draft plans. Since `persist-intake-plan-drafts` is the next child change, this could make router apply workers implement draft-plan discovery too early.

Why it matters: That would blur child-change boundaries and make `scope_dependency_check` delete or reshuffle implementation work later.

Modification:

- Narrowed router inputs to active plans plus draft plan titles only when a downstream draft-persistence surface already exists.
- Added an explicit design note that this router change must not implement draft-plan persistence/discovery.
- Updated study-intake and learning-data-layer specs to say "active plan or available downstream draft-plan surface."
- Renamed the broad data-layer requirement from `Role-Based Learning Entities` to `Role-Based Intake Relationships`.

## Product Model Review

- The child change now has a cleaner first-slice boundary: intake routing and non-plan safety only.
- `persist-intake-plan-drafts` remains responsible for actual draft state, versioning, and draft query/persistence surfaces.
- Downstream contracts are named, but downstream behavior is not implemented here.

## Recommended Next Actions

- Must address before apply: none remaining after this round.
- Needs user scope decision: none.
- Next checkpoint: `scope_dependency_check` for `introduce-study-intake-router`.

## Result

Round 3 completed the scope-aware product-deepen pass and tightened the boundary between router and draft persistence. `introduce-study-intake-router` is ready for the dedicated scope dependency check.
