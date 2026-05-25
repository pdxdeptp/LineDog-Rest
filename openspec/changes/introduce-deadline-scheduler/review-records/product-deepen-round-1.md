# Product Deepen Round 1: introduce-deadline-scheduler

- Automation: add-initiate-changes
- Checkpoint: introduce-deadline-scheduler:product_deepen_round_1
- Skill: opsx-product-deepen
- Result: P0 fixes applied
- Completed at: 2026-05-25T10:59:11Z

## Change Understanding

This change turns validated compiler task candidates into a dated review draft. It owns deterministic date placement, capacity math, buffer/risk reporting, infeasibility option generation, and option-effect recomputation. It does not generate tasks, persist active tasks, render UI, or activate anything.

Boundary is now clearer after this round: scheduler starts only from compiler `draft_review` packages and returns a pure `ScheduledDraftReview` review payload.

## Adjacent Changes Read

- Upstream `introduce-plan-compiler`: owns envelope normalization, archetype/depth semantics, task candidates, estimates, split points, fallback modes, low calibration, and trace. It deliberately emits no dates, no capacity gap, no buffer erosion, and no `infeasible_review`.
- Downstream `redesign-add-initiate-ui`: owns rendering role/anchor/progress/draft/infeasible states, option controls, retry/edit/cancel/activate, and Today/noise exclusion.

## Experience Loops

### Feasible Scheduling Loop

- Goal: show a believable draft plan with dates and buffer without user maintenance burden.
- Entry: compiler `draft_review` package plus anchors.
- Main path: build date window, calculate capacity, reserve buffer, place essential work, then optional/stretch.
- Success state: `draft_review` with scheduled days, risk summary, and no unaccepted essential risk.
- Failure state: any essential late/unscheduled/over-capacity/unaccepted buffer risk enters `infeasible_review`.
- Feedback: scheduled days, load state, buffer summary, low-calibration summary, trace.
- Coverage after edits: complete enough for TDD.

### Infeasible Review Loop

- Goal: expose concrete scheduling facts and deterministic choices.
- Entry: capacity gap, expected-late work, overload, buffer erosion, or low calibration.
- Main path: map facts to canonical option ids and recompute a new review or handoff.
- Success state: new `ScheduledDraftReview`, storage state, or compiler-recompute handoff.
- Failure state: no silent fix, no activation.
- Feedback: facts first, option effect summary, hard-deadline guardrails.
- Coverage after edits: complete enough for TDD.

## Deep Issues

### P0: Output Contract Was Too Implicit

- Problem: design said "return scheduled tasks and risk report" but did not define the review payload, day row, scheduled item, status derivation, or trace boundary.
- Why it matters: implementation workers would invent incompatible shapes, and UI/draft persistence would guess how to consume them.
- Fix applied: added `ScheduledDraftReview`, `ScheduledDay`, scheduled item, risk/options/trace fields, and tasks for output-shape tests.
- Destination: design, spec delta, tasks.
- Scope impact: in scope; clarifies scheduler API without adding UI/persistence.

### P0: Scheduler Status Boundary Was Ambiguous

- Problem: docs did not state whether scheduler should schedule compiler `needs_input` or `compile_failed`, or when to return `draft_review` versus `infeasible_review`.
- Why it matters: scheduler could accidentally convert recovery states into fake dated work, or treat optional overflow as infeasible essential failure.
- Fix applied: scheduler accepts only compiler `draft_review`; `draft_review` and `infeasible_review` are derived from essential work fit and unaccepted risk.
- Destination: design, spec delta, tasks.
- Scope impact: in scope; protects upstream/downstream contracts.

### P0: Option Effects Could Be Mistaken For Activation

- Problem: option effects were listed as verbs but not identified as pure recomputation/storage/handoff outcomes.
- Why it matters: an apply worker could mutate active tasks or silently apply tradeoffs.
- Fix applied: option effects now return a new scheduled review, storage state, or compiler-recompute handoff; they do not activate.
- Destination: design, spec delta, tasks.
- Scope impact: in scope; avoids UI/persistence drift.

## Scope Decisions

### In Scope

- deterministic scheduler review output shape;
- review status derivation;
- inclusive date-window rules;
- capacity and buffer math;
- continuation-session identity preservation;
- deterministic infeasibility option effects as review recomputation or handoff.

### Out Of Scope

- compiler regeneration for lower-depth outputs;
- UI rendering and option controls;
- active-task writes and Today creation;
- moving existing active tasks;
- broad LLM calendar generation.

### Deferred Upstream Dependencies

- Compiler must continue providing task candidates, estimates, confidence/calibration, split points, fallback modes, and reducible/depth-obligation metadata.
- Lower-depth and answer-one-question effects require compiler recomputation; scheduler only returns handoff facts.

### Downstream Contracts Preserved

- UI receives statuses and canonical option ids but owns labels, controls, expansion, retry/edit/cancel/activation.
- Draft persistence can store scheduler review payloads and versions but physical persistence remains outside this change.

## Product Model Review

Concepts introduced or clarified:

- `ScheduledDraftReview`
- `ScheduledDay`
- `ScheduleRiskReport`
- `scheduler_trace`
- `compiler_recompute_required`

Names match the user-facing model because the scheduler is still a draft review, not active tasks.

## Recommended Next Actions

- Must address before apply: none remaining from Round 1 after edits.
- Needs user scope decision: none.
- Future proposals: richer user calendar preferences, automatic active-load rebalancing.
- Explicit non-goals: activation, UI, compiler regeneration, moving active tasks.

