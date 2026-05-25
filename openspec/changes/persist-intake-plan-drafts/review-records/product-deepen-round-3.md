# Product Deepen Round 3: Existing-Plan Targets And Activation Idempotency

## Metadata

- Change: `persist-intake-plan-drafts`
- Round: 3
- Timestamp: 2026-05-25T06:10:40Z
- Skill: `opsx-product-deepen`

## Change Understanding

Round 1 made the draft storage contract concrete. Round 2 made migration, entry points, and lifecycle transitions implementable. Round 3 challenged the remaining boundary between the completed router change and downstream compiler/scheduler changes.

The main risk was a subtle handoff gap: the router can classify `attach_to_existing_plan` into `draft_phase` or `scheduled_work`, but draft persistence must store whether activation creates a new plan or appends work to an existing active plan. Without that contract, implementation could accidentally create duplicate top-level resources, lose the selected target plan, or make duplicate activation retries destructive.

## Adjacent Changes Read

Upstream: `introduce-study-intake-router`

- Provides durable intake items and role confirmation.
- For existing-plan attachments, validates the active plan target before creating the intake item.
- Returns handoff states for `new_plan`, `draft_phase`, and `scheduled_work`.
- Does not create plan drafts or active tasks.

Downstream: `introduce-plan-compiler`

- Owns generation of task candidates, phases, estimates, blocked package states, and validation traces.
- Requires draft persistence to preserve draft id/version/status/assumptions/activation eligibility.
- Should not decide active-resource creation semantics.

Downstream: `introduce-deadline-scheduler`

- Owns deterministic schedule slices, capacity placement, buffer rules, and infeasibility reports.
- Requires activation to consume persisted schedule-ready data, not generate dates.
- Should not repair draft target-plan identity during activation.

## Experience Loops Reviewed

### Existing-Plan Draft Creation

- Entry: router confirms `attach_to_existing_plan` with `draft_phase` or `scheduled_work`.
- Success: draft persistence records `draft_kind` and `target_plan_id`.
- Failure: missing or inactive target plan is rejected before activation-ready work is created.
- Coverage after edits: improved.

### Existing-Plan Activation

- Entry: user activates a draft that targets an existing active plan.
- Success: units/tasks append under the recorded target plan and no new top-level resource is created.
- Failure: if the target plan is no longer active, activation fails before active rows are inserted.
- Coverage after edits: improved.

### Duplicate Activation Retry

- Entry: caller retries activation after a previous success.
- Success: data layer returns the existing activation event or rejects with `already_activated`.
- Failure: no duplicate active resources, units, or tasks are created.
- Coverage after edits: improved.

### Discard After Activation

- Entry: caller tries to discard a draft after it reached `active_plan`.
- Success: request is rejected as the wrong lifecycle operation.
- Failure: active plan rows remain untouched.
- Coverage after edits: improved.

## Deep Issues

### P0: Existing-Plan Handoff Could Lose Its Target

- Problem: The router can hand off existing-plan phase/scheduled-work items, but persistence did not require `draft_kind` and `target_plan_id`.
- Why it matters: Activation could create a new resource when the user intended to append to an existing plan.
- Applied direction: Added draft kind and target-plan semantics to the design, data-layer spec, and tasks.
- Destination: `design.md`, `learning-data-layer/spec.md`, `study-intake-planning/spec.md`, `tasks.md`.
- Scope impact: In-scope persistence and activation target semantics only; router classification is already upstream.

### P0: Duplicate Activation Retry Needed Non-Destructive Semantics

- Problem: Activation checks rejected stale versions but did not specify what happens if the same valid version is activated twice due to retry.
- Why it matters: A network retry or automation recovery could create duplicate active work.
- Applied direction: Defined duplicate activation as idempotency-safe: return existing activation event or reject with `already_activated`, never create duplicate rows.
- Destination: `design.md`, `learning-data-layer/spec.md`, `tasks.md`.
- Scope impact: In-scope data-layer transaction safety.

### P1: Discard Semantics After Activation Were Ambiguous

- Problem: Pre-activation discard was safe, but the docs did not say whether discard remains available after activation.
- Why it matters: A later cleanup action could mutate active tasks through a draft operation.
- Applied direction: Explicitly rejected draft discard after `active_plan`; later changes must use active-plan adjustment flows.
- Destination: `design.md`, `learning-data-layer/spec.md`, `study-intake-planning/spec.md`, `tasks.md`.
- Scope impact: In-scope lifecycle guard; adjustment behavior stays downstream/out of scope.

## Scope Decisions

### In Scope

- Persisting `draft_kind` and optional `target_plan_id`.
- Validating existing-plan targets at draft creation and activation time.
- Activation behavior for new-plan versus existing-plan draft kinds.
- Duplicate activation idempotency safety.
- Rejecting draft discard after activation.
- Tests for target-plan activation, duplicate activation, and discard-after-activation guards.

### Out Of Scope

- Choosing the existing plan target in the UI.
- Router role classification changes.
- Compiler generation of phases/tasks.
- Scheduler date placement or risk reports.
- Active-plan adjustment after activation.

### Deferred Upstream Dependencies

- None blocking. The router already provides role, attachment mode, and existing-plan validation. This change only persists and enforces those handoff facts.

### Downstream Contracts Preserved

- `introduce-plan-compiler` can store generated packages against a stable draft id/version and does not own active-resource creation decisions.
- `introduce-deadline-scheduler` can persist schedule slices later and does not own target-plan identity.
- `redesign-add-initiate-ui` can present activation/discard outcomes without implementing persistence guards.

## Files Updated

- `openspec/changes/persist-intake-plan-drafts/design.md`
- `openspec/changes/persist-intake-plan-drafts/specs/learning-data-layer/spec.md`
- `openspec/changes/persist-intake-plan-drafts/specs/study-intake-planning/spec.md`
- `openspec/changes/persist-intake-plan-drafts/tasks.md`

## Validation

- `openspec validate persist-intake-plan-drafts --strict`: valid.

## Result

Round 3 closed the remaining existing-plan and activation-retry gaps without adding compiler, scheduler, or UI behavior. After validation, the next checkpoint is `scope_dependency_check` for this change.
