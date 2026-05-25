# Product Deepen Round 1: Draft Persistence Storage Contract

## Metadata

- Change: `persist-intake-plan-drafts`
- Round: 1
- Timestamp: 2026-05-25T06:10:40Z
- Skill: `opsx-product-deepen`

## Change Understanding

This change owns durable draft state after routing and before compiler/scheduler/UI implementation. It must let later changes store compiler outputs, draft versions, assumptions, activation events, and fallback progress without leaking drafts into active Today/Calendar facts.

The current boundary is mostly right, but the first pass was too abstract for apply: it named `PlanDraft`, `DraftPhase`, `DraftTask`, and `ActivationEvent` without enough storage, versioning, and activation-transaction detail.

## Adjacent Changes Read

Upstream: `introduce-study-intake-router`

- Router creates durable `study_intake_items`.
- Plan-generating confirmations move intake items to `awaiting_anchor_review`.
- Router does not implement draft persistence, compiler, scheduler, or UI.

Downstream: `introduce-plan-compiler`

- Compiler expects a versioned draft package shell with assumptions, status, task candidates, validation states, and trace.
- Compiler owns phase/task generation and estimate normalization.
- Compiler must not own persistence internals or activation transaction safety.

## Experience Loops Reviewed

### Draft Creation / Anchor Review

- Entry: router handoff returns `awaiting_anchor_review`.
- Success: draft header linked to intake item exists with status and assumption shell.
- Failure: invalid intake state or missing anchor facts creates a non-active draft state, not active tasks.
- Coverage after edits: improved.

### Draft Version Edit

- Entry: user/compiler changes assumptions, scope, estimates, tasks, or schedule-affecting settings.
- Success: new immutable draft version snapshot exists; previous versions remain recoverable.
- Failure: non-meaningful metadata edits must not create noisy versions.
- Coverage after edits: improved.

### Activation Boundary

- Entry: user requests activation for a draft version.
- Success: latest activatable version creates active rows and activation event in one transaction.
- Failure: stale or incomplete draft is rejected before active rows are inserted.
- Coverage after edits: improved.

### Fallback Completion

- Entry: user completes low-energy fallback for an active task.
- Success: fallback timestamp/minutes/follow-up are persisted without full completion.
- Failure: full `completed_at` remains unset unless the full task is separately completed.
- Coverage after edits: improved.

## Deep Issues

### P0: Physical Draft Contract Was Too Abstract

- Problem: The docs named logical entities but did not define the fields implementation workers must persist.
- Why it matters: Apply could either under-model drafts or reuse legacy `study_project_drafts` in a way that cannot support downstream compiler/scheduler contracts.
- Applied direction: Added explicit logical field contracts for draft headers, assumptions, phases, tasks, schedule slices, and activation events.
- Destination: `design.md`, `learning-data-layer/spec.md`, `tasks.md`.
- Scope impact: Stays inside draft persistence. No compiler/scheduler logic added.

### P0: Versioning Semantics Were Ambiguous

- Problem: "Every meaningful edit creates a version" did not define snapshot behavior, latest activatable version, or non-meaningful edits.
- Why it matters: Stale activation rejection and rollback tests need deterministic version semantics.
- Applied direction: Defined snapshot-based V1, read-only previous versions, latest activatable version rules, and display-only edit exception.
- Destination: `design.md`, `learning-data-layer/spec.md`, `tasks.md`.
- Scope impact: In-scope for persistence and tests.

### P0: Activation Could Accidentally Become Scheduler Work

- Problem: The draft persistence change said activation creates active tasks, but did not say whether it can generate dates/tasks.
- Why it matters: Workers could implement scheduling in this change or insert partial active rows.
- Applied direction: Defined activation as guarded data-layer transaction consuming already persisted activation-ready draft data; no generation or date placement during activation.
- Destination: `design.md`, `learning-data-layer/spec.md`, `tasks.md`.
- Scope impact: Prevents scope drift to `introduce-deadline-scheduler`.

### P0: Assumption Provenance Was Not Concrete

- Problem: Provenance was required but no allowed values or fact-level expectations were defined.
- Why it matters: Compiler and UI cannot explain assumptions if storage is inconsistent.
- Applied direction: Added V1 provenance enum and facts requiring value/provenance preservation.
- Destination: `design.md`, `learning-data-layer/spec.md`.
- Scope impact: In-scope persistence only.

### P0: Fallback Completion Boundary Needed Active-Task Semantics

- Problem: Fallback persistence was described but did not explicitly forbid setting full completion.
- Why it matters: A low-energy fallback could erase remaining work.
- Applied direction: Defined fallback fields and tests proving fallback-only does not set `completed_at`.
- Destination: `design.md`, `tasks.md`.
- Scope impact: In-scope active task progress persistence; no adjustment behavior implemented.

## Scope Decisions

### In Scope

- Draft header storage linked to router intake item.
- Draft lifecycle status persistence.
- Draft assumption and provenance storage.
- Draft version snapshots and latest-version activation guard.
- Activation event persistence and transaction rollback.
- Fallback progress persistence separate from full completion.
- Capacity default regression.

### Out Of Scope

- Intake role routing.
- LLM phase/task generation.
- Deterministic scheduling or date placement.
- Add / Initiate UI.
- Smart-mode or adjustment behavior after activation.

### Deferred Upstream Dependencies

- None blocking. Router already provides intake item ids, roles, confirmation state, and `awaiting_anchor_review` handoff.

### Downstream Contracts Preserved

- `introduce-plan-compiler` owns phase/task generation, estimate normalization, compiler trace, and compiler package contents.
- `introduce-deadline-scheduler` owns deterministic final date placement.
- `redesign-add-initiate-ui` owns review/activation UI.

## Files Updated

- `openspec/changes/persist-intake-plan-drafts/design.md`
- `openspec/changes/persist-intake-plan-drafts/specs/learning-data-layer/spec.md`
- `openspec/changes/persist-intake-plan-drafts/specs/study-intake-planning/spec.md`
- `openspec/changes/persist-intake-plan-drafts/tasks.md`

## Validation

- `openspec validate persist-intake-plan-drafts --strict`: valid.

## Result

Round 1 addressed the P0 storage and boundary ambiguity. Continue to Round 2 to challenge migration/backward compatibility, lifecycle transitions, and test grouping.
