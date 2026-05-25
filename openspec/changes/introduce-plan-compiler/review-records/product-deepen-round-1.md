# Product Deepen Round 1: Boundary Contracts And Compiler Status

## Change Understanding

`introduce-plan-compiler` owns the middle of Add / Initiate: it turns a confirmed planning intent and persisted draft shell into validated phases and executable task candidates. It does not route intake, persist draft internals, assign dates, compute schedule fit, render UI, or activate tasks.

The current direction was right, but implementation workers could still guess the exact `PlanningEnvelope`, compiler result statuses, low-calibration semantics, and scheduler handoff fields. That ambiguity is dangerous because this change sits between already-implemented draft persistence and the downstream deadline scheduler.

## Adjacent Changes Read

- Upstream: `persist-intake-plan-drafts` proposal/design/specs/tasks and cross-change contract evidence.
- Downstream: `introduce-deadline-scheduler` proposal/design/specs/tasks.

## Experience Loops

### Compile To Draft Review

- Goal: produce structurally valid phases and task candidates for later deterministic scheduling.
- Entry: draft shell has confirmed role and anchors.
- Main path: normalize envelope, select archetype/scope, generate phases/tasks, validate/repair, normalize estimates, return `draft_review`.
- Success state: unscheduled compiler package with trace and no final dates.
- Failure state: `needs_input` or `compile_failed`.
- Feedback: visible assumptions, missing facts, validation errors, and low-calibration flag.
- Coverage after edits: complete enough for apply.

### Blocked Compilation

- Goal: stop safely when anchors or generated structure are not reliable.
- Entry: missing target output/depth/source facts or unrepaired schema/quality failure.
- Main path: return `needs_input` with one focused question, or `compile_failed` with validation errors and recovery actions.
- Success state: persistence can store a blocked package without complete phases/tasks.
- Failure state: none; this is the safe terminal state before user recovery.
- Coverage after edits: complete.

## Deep Issues

### P0: Boundary Contract Was Too Implicit

- Problem: `PlanningEnvelope` and `CompilerResult` were named but not shaped tightly enough.
- Why it matters: apply could invent incompatible keys, and scheduler/UI changes would have to guess which facts are pass-through versus compiler-owned.
- Action: added `Boundary Contracts`, a V1 `PlanningEnvelope`, upstream handoff fields, compiler result statuses, and status-specific package requirements to `design.md`.
- Destination: design/spec/tasks.
- Scope impact: in scope; contract clarification only.

### P0: Compiler Could Drift Into Scheduler Status

- Problem: the surrounding data layer supports `infeasible_review`, but this change must not compute schedule infeasibility.
- Why it matters: if the compiler emits capacity-gap or overloaded-date facts, it absorbs `introduce-deadline-scheduler`.
- Action: made `draft_review`, `needs_input`, and `compile_failed` the only compiler statuses; `low_calibration` is a flag; `infeasible_review` is scheduler-owned.
- Destination: design/spec/tasks.
- Scope impact: narrows scope.

### P0: Scheduler-Needed Task Fields Were Missing

- Problem: task candidates lacked explicit `work_type` and essential/optional/stretch classification.
- Why it matters: downstream scheduler cannot place essential work first, reduce scope honestly, or apply work-type estimate defaults without those fields.
- Action: added work type, classification, depth-obligation/reducible reason to task contract and tests.
- Destination: design/spec/tasks.
- Scope impact: in scope; required downstream contract.

### P0: Low Calibration Was Untestable

- Problem: "significant share" of low-confidence estimates was not measurable.
- Why it matters: tests cannot assert when a draft is rough but structurally valid.
- Action: added V1 low-calibration thresholds.
- Destination: design/spec.
- Scope impact: in scope; deterministic acceptance criterion.

## Scope Decisions

### In Scope

- Compiler input/output contracts.
- Status-specific compiler package behavior.
- Task candidate fields required by deterministic scheduling.
- Low-calibration thresholds.

### Out Of Scope

- Intake routing and role confirmation.
- Physical draft table migrations or activation transactions.
- Final date placement, per-day capacity fit, buffer erosion, expected-late facts, and schedule risk.
- Add / Initiate UI states.

### Deferred Upstream Dependencies

- Source summaries are not guaranteed to be precomputed by draft persistence. The compiler must build source/goal synopsis from available shallow facts and mark missing facts or low calibration.
- Draft assumptions may be legacy or unknown; the compiler must treat them as missing/assumed rather than trusting them as accepted user facts.

### Downstream Contracts Preserved

- Scheduler receives ordered, validated, unscheduled task candidates with estimates, dependency order, work type, essential/optional/stretch classification, fallback mode, and split points.
- Scheduler owns dates, capacity-gap math, infeasibility options, buffer erosion, overloaded dates, and `infeasible_review`.

## Product Model Review

- Concepts now align with split ownership: draft persistence stores packages, Plan Compiler creates unscheduled structure, scheduler places it on dates.
- `low_calibration` remains a flag instead of becoming another lifecycle state.
- Task importance and work type are implementation-facing fields, not noisy user-facing todos.

## Recommended Next Actions

- Round 2 should deepen archetype selection, source synopsis, LLM schema, validation, and repair behavior.
- Round 3 should deepen real-context dry runs and acceptance coverage.
