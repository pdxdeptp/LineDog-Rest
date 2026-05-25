# Product Deepen Round 3: introduce-deadline-scheduler

- Automation: add-initiate-changes
- Checkpoint: introduce-deadline-scheduler:product_deepen_round_3
- Skill: opsx-product-deepen
- Result: P0 preflight clarification applied
- Completed at: 2026-05-25T10:59:11Z

## Change Understanding

Round 3 checked whether the scheduler would still behave safely when required scheduling anchors are absent or malformed. The important correction: not every scheduler failure is infeasibility. Missing deadline or empty schedulable task input should return a minimal `needs_input`/recovery shape, not a fake impossible plan.

This keeps the first-version goal intact: the assistant only schedules when a deadline-driven plan can be honestly constructed.

## Adjacent Changes Read

- Upstream `introduce-plan-compiler`: may provide `needs_input` or `compile_failed`; scheduler must pass those through instead of scheduling them.
- Upstream completed handoff evidence: compiler passes deadline/capacity/rest/buffer anchors when available but does not own date placement.
- Downstream `redesign-add-initiate-ui`: already includes `needs_input`, `compile_failed`, `infeasible_review`, and `draft_ready` review states, so scheduler `needs_input` can be shown without inventing active tasks.

## Experience Loops

### Scheduler Preflight Loop

- Goal: avoid guessing deadlines or manufacturing placeholder tasks.
- Entry: compiler `draft_review` package arrives at scheduler.
- Main path: validate required anchors, apply safe defaults, then place tasks.
- Success state: placement proceeds with visible assumptions.
- Failure state: scheduler returns `needs_input` for missing deadline, invalid date parsing, or empty schedulable task set.
- Feedback: one focused question or recovery reason; no scheduled days required.
- Coverage after edits: complete.

### Scope Boundary Loop

- Goal: keep scheduler from absorbing compiler or UI responsibilities while still returning actionable review facts.
- Entry: option effects or invalid inputs.
- Main path: recompute schedule, storage result, or compiler-recompute handoff.
- Success state: current change remains deterministic scheduling.
- Failure state: implementation tries to regenerate tasks, render UI, persist activation, or move existing active tasks.
- Feedback: explicit non-goals and downstream contracts.
- Coverage after edits: complete.

## Deep Issues

### P0: Missing Deadline Was Not Modeled

- Problem: the scheduler output contract only allowed `draft_review` and `infeasible_review`. Missing deadline is neither; it is missing input.
- Why it matters: implementation could invent a deadline, use today as both start and deadline, or mark the draft infeasible for the wrong reason.
- Fix applied: scheduler output status now includes `needs_input` for missing/invalid required scheduling anchors, with at most one focused question and no scheduled days required.
- Destination: design, spec delta, tasks.
- Scope impact: in scope; aligns with downstream UI recovery state.

### P0: Defaultable Versus Required Anchors Were Mixed

- Problem: daily capacity has a known default, but deadline does not. Existing load/rest/unavailable can default empty, but those assumptions must be visible.
- Why it matters: hidden defaults can make generated plans look more certain than they are.
- Fix applied: added scheduler preflight defaults and visible assumption requirements; missing deadline, invalid dates, and empty task sets block scheduling as `needs_input`.
- Destination: design, spec delta, tasks.
- Scope impact: in scope.

## Scope Decisions

### In Scope

- scheduler input preflight;
- safe defaulting for start date, deadline type, capacity, load, rest/unavailable dates, and buffer policy;
- scheduler `needs_input` for missing deadline, invalid date parsing, or empty schedulable task candidates;
- tests for preflight and visible assumptions.

### Out Of Scope

- collecting the missing deadline in UI;
- compiler task regeneration;
- persistence conflict resolution;
- activation or Today writes.

### Deferred Upstream Dependencies

- Draft persistence/UI should normally collect or assume deadline before invoking scheduler.
- Compiler remains responsible for producing valid task candidates; scheduler only protects against absent schedulable input.

### Downstream Contracts Preserved

- UI can reuse its `needs_input` state and show one scheduler-focused question.
- UI still owns retry/edit/cancel/activation.
- Draft persistence stores review versions; this change only returns deterministic payloads.

## Product Model Review

The scheduler model now has three review outcomes:

- `needs_input`: cannot schedule without a required anchor or schedulable task set;
- `draft_review`: essential work fits without unaccepted risk;
- `infeasible_review`: essential work needs a user tradeoff.

This is less tidy than two states, but it matches user reality and prevents fake plans.

## Recommended Next Actions

- Must address before apply: none remaining after Round 3 edits.
- Needs user scope decision: none.
- Future proposals: richer stale-version conflict handling between UI and stored draft versions.
- Explicit non-goals: UI input collection, persistence writes, compiler regeneration, active-task mutation.

