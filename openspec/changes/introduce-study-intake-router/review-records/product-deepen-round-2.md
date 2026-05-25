# Product Deepen Round 2

## Change Understanding

`introduce-study-intake-router` owns the first Add / Initiate slice: accept one submitted item, create an idempotent intake item, preview sources safely, recommend a machine role, clarify ambiguity with at most one question, and store or hand off without creating active tasks.

This round reviewed the quality of the Round 1 fixes before apply.

## Experience Loops Reviewed

### Intake Submission And Idempotent Routing

- Goal: one submitted item creates at most one pending route outcome.
- Entry: UI/backend submits `IntakeSubmission` with `clientRequestId`.
- Main path: return `IntakeRouteResult` with role, confidence, reason codes, next action, and `createsActiveTasks=false`.
- Success state: one reusable intake item and one pending action.
- Failure state: unsupported/ambiguous input returns manual title/description or one routing question.
- Coverage: complete enough for apply.

### Existing-Plan Attachment Resolution

- Goal: avoid guessing which existing plan receives material or scheduled work.
- Entry: router recommends or user confirms `attach_to_existing_plan`.
- Main path: require `existingPlanId` and `attachmentMode` before handoff.
- Success state: material-only stores safely, draft/scheduled work waits for later anchor review.
- Failure state: target selection or clarification next action.
- Coverage: complete enough for apply.

### GitHub Source Role Handling

- Goal: keep source/repo role separate from workflow/intake role.
- Entry: submitted GitHub repo.
- Main path: shallow preview may set `canonicalRepoRole`; route still uses `recommendedRole`.
- Success state: no enum drift between repo roles and machine roles.
- Coverage: complete enough for apply.

## Deep Issues

No new P0 issues found.

### P1: Implementation should inventory existing data/API names during apply

Problem: The OpenSpec intentionally defines logical contracts rather than physical endpoint/table names.

Why it matters: Apply workers must map these contracts onto the current codebase without inventing parallel duplicate APIs or storage.

Suggested direction: Handle during apply planning and apply by first locating current material ingestion, learning data, and Today-query seams.

Artifact decision: No spec change. This is an implementation-readiness concern, not a product requirement gap.

### P2: One-off action UX can be refined later

Problem: Router safely prevents `immediate_one_off` from entering Today automatically, but the final UI affordance for explicit one-off scheduling belongs to the UI child change.

Why it matters: Keeping it out of this router change prevents scope creep.

Artifact decision: No change. Leave UI details to `redesign-add-initiate-ui`.

## Product Model Review

- The Round 1 router contracts are coherent: `IntakeSubmission`, `IntakeRouteResult`, `RoleConfirmation`, and `RouterOutcome` now give implementation enough shape.
- The intake role versus source/repo role split is clear.
- Idempotency now supports long-running automation and UI retries.
- Existing-plan target resolution is guarded enough to avoid accidental scheduled-work handoff.
- The boundary remains clear: this change routes and stores non-plan outcomes; it does not compile plans or schedule dates.

## Recommended Next Actions

- Must address before apply: none found in this round.
- Needs user scope decision: none.
- Next checkpoint: continue through the control-file state machine toward apply.

## Result

Round 2 confirms that `introduce-study-intake-router` is ready to move toward apply, subject to the normal pre-apply planning and fresh `openspec validate`.

## Scope Decisions Addendum

Added during the 2026-05-25 scope dependency audit after the automation policy began requiring explicit scope decisions in every product-deepen record. This addendum records the boundary verified by Round 2; it does not change the original readiness conclusion.

### In Scope

- Intake submission idempotency and one-pending-object behavior.
- Logical router contracts and confirmation payloads.
- Existing-plan attachment target selection and attachment-mode confirmation.
- GitHub/source role separation from intake machine roles.
- Storage or handoff outcomes that remain outside Today until explicit activation.

### Out Of Scope

- Creating or persisting full plan drafts.
- Discovering/querying draft plans as part of router implementation.
- LLM task generation, deterministic scheduling, and active task creation.
- UI details for explicit one-off scheduling.

### Deferred Upstream Dependencies

- None. This change has no earlier Add / Initiate child-change dependency.

### Downstream Contracts Preserved

- Downstream draft persistence can consume `intakeItemId`, `confirmedRole`, `attachmentMode`, optional `existingPlanId`, `canonicalRepoRole`, and `materialRole`.
- The router may name a downstream handoff state, but draft lifecycle, draft versions, and activation records stay outside this change.
