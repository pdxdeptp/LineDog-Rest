# Product Deepen Round 1

## Change Understanding

`introduce-study-intake-router` is the first implementation slice of the Add / Initiate redesign. Its job is to create one intake item, preview sources safely, recommend a role, clarify ambiguity with at most one question, and store non-plan outcomes without creating active tasks.

It explicitly does not compile plans, schedule dates, activate tasks, or build the final Add / Initiate UI.

## Experience Loops Reviewed

### Intake Submission And Routing

- Goal: turn one submitted item into one pending role decision or safe stored outcome.
- Entry: user submits text, URL, GitHub repo, note, project item, interview prep, or resume/project material.
- Main path: create idempotent intake item, preview source when useful, recommend role, return next action.
- Success: one role-review or storage decision; no active tasks.
- Failure: unsupported/ambiguous input returns manual title/description or one question.
- Coverage before this round: partial.

### Existing-Plan Attachment

- Goal: attach support/material/work intent to an existing plan without schedule mutation.
- Entry: router recommends or user chooses `attach_to_existing_plan`.
- Main path: confirm target plan and attachment mode.
- Success: material-only stores safely, scheduled modes hand off to later anchor review.
- Failure: target plan missing or ambiguous.
- Coverage before this round: partial.

### GitHub Role Handling

- Goal: use shallow GitHub facts without converting repos into tasks.
- Entry: user submits GitHub repo.
- Main path: preview metadata, recommend intake role and separate canonical repo role.
- Success: role and repo role are distinct.
- Coverage before this round: partial.

## Deep Issues

### P0: Router contracts were too implicit

Problem: The change named the router roles but did not define stable input/output contracts, next actions, or confirmation payloads.

Why it matters: Implementation could invent incompatible endpoints or states, making later UI/compiler integration brittle.

Modification: Added `IntakeSubmission`, `IntakeRouteResult`, `RoleConfirmation`, and `RouterOutcome` logical contracts to `design.md`; added route result scenario to `study-intake-planning` spec; added route-contract tasks.

### P0: Idempotency was missing

Problem: The router promises one pending object per submitted item, but did not define retry behavior.

Why it matters: UI/network retries or heartbeat calls could create duplicate pending role confirmations or duplicate stored resources.

Modification: Added `clientRequestId` idempotency requirements in design, data-layer spec, study-intake spec, and tests.

### P0: Existing-plan attachment target resolution was underspecified

Problem: The docs said `attach_to_existing_plan` can use `material_only`, `draft_phase`, or `scheduled_work`, but did not require a confirmed target plan before handoff.

Why it matters: Scheduled-work handoff without a target plan would force implementation to guess, or silently create work in the wrong plan.

Modification: Added target-selection next action and requirement that both `existingPlanId` and `attachmentMode` are confirmed before handoff.

### P1: Repo role versus intake role could still be confused

Problem: GitHub repo roles were listed, but the child change did not explicitly say they are separate from machine intake roles.

Why it matters: A repo role like `clone_rebuild_target` could be accidentally implemented as a route role, recreating enum drift across child changes.

Modification: Treated as coherence-critical for this child change and added explicit separation in design/spec/tasks.

## Product Model Review

- Concepts are now cleaner: intake role controls workflow; source/repo role describes the submitted material.
- Defaults remain conservative: no active tasks from routing.
- The router now has enough state and contract surface for UI/compiler handoff without owning later stages.

## Result

Round 1 found and fixed the missing router contract, idempotency, attachment-target, and repo-role separation details. The change remains scoped to routing and non-plan safety.
