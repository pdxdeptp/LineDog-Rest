# Scope Dependency Check: introduce-plan-compiler

## Metadata

- Automation: add-initiate-changes
- Checkpoint: introduce-plan-compiler:scope_dependency_check
- Completed at: 2026-05-25T09:05:11Z
- Result: passed

## Artifacts Read

Current change:

- `openspec/changes/introduce-plan-compiler/proposal.md`
- `openspec/changes/introduce-plan-compiler/design.md`
- `openspec/changes/introduce-plan-compiler/tasks.md`
- `openspec/changes/introduce-plan-compiler/specs/study-intake-planning/spec.md`
- `openspec/changes/introduce-plan-compiler/review-records/product-deepen-round-1.md`
- `openspec/changes/introduce-plan-compiler/review-records/product-deepen-round-2.md`
- `openspec/changes/introduce-plan-compiler/review-records/product-deepen-round-3.md`

Adjacent upstream change:

- `openspec/changes/persist-intake-plan-drafts/design.md`
- `openspec/changes/persist-intake-plan-drafts/specs/study-intake-planning/spec.md`

Adjacent downstream change:

- `openspec/changes/introduce-deadline-scheduler/design.md`
- `openspec/changes/introduce-deadline-scheduler/specs/study-intake-planning/spec.md`

## Product-Deepen Record Coverage

All three product-deepen records include explicit scope decisions:

- Round 1 records in-scope compiler contracts/statuses, out-of-scope draft table internals, activation, UI, and scheduler facts; it also records deferred upstream source-summary/legacy-assumption dependencies and downstream scheduler contracts.
- Round 2 records in-scope archetype/synopsis/LLM validation/repair work, out-of-scope deep parsing/date placement/UI wording, deferred richer material parsing and legacy assumption typing, and downstream scheduler ownership of dates, option math, and `infeasible_review`.
- Round 3 records in-scope real-context fixture acceptance and sensitive-content boundaries, out-of-scope dated schedule dry runs, capacity math, broad Obsidian/GitHub ingestion, and downstream scheduler/UI/persistence contracts.

## In-Scope Boundary

`introduce-plan-compiler` owns:

- normalized `PlanningEnvelope` creation from persisted draft shell, anchors, source roles/facts, existing-plan context, and provenance;
- compiler result statuses `draft_review`, `needs_input`, and `compile_failed`, with `low_calibration` as a review flag;
- deterministic archetype and scope selection, tie-breakers, and one-question ambiguity handling;
- source/goal synopsis from shallow facts;
- target-depth semantics and completion obligations;
- structured LLM phase/task/repair contracts;
- task quality gates, bounded repair, estimate normalization, and compiler trace;
- sensitive-content boundaries and real-context unscheduled compiler fixtures.

## Out-Of-Scope Boundary

The current change does not own:

- intake routing or role confirmation;
- physical draft table migrations, draft shell idempotency, lifecycle status persistence, activation events, or active task creation;
- deterministic date placement, usable-capacity math, buffer reservation/erosion, overload, expected-late, capacity gap, or `infeasible_review`;
- UI controls, labels, progress streams, or review surfaces;
- deep GitHub crawling, broad Obsidian vault sync, or automatic private repo source reading.

## Upstream Contract Check

Upstream `persist-intake-plan-drafts` provides the required handoff:

- intake-linked draft identity: draft id, draft version, intake id, draft kind, optional target plan id, and status;
- assumption persistence for deadline, capacity, target output, target depth, buffer policy, rest/unavailable days, source roles, and provenance;
- compiler package shell persistence for review, `needs_input`, and `compile_failed` packages;
- versioning and activation boundaries that keep draft tasks separate from active Today/Calendar facts.

Deferred upstream dependencies are explicitly named and acceptable:

- source summaries may be shallow or absent; the compiler builds a bounded synopsis from available facts and marks missing facts or low calibration;
- legacy draft assumptions may be unknown; the compiler treats them as missing/assumed rather than accepted user facts;
- richer material ingestion can improve future source facts but is not required for V1 compiler apply.

## Downstream Contract Check

Downstream `introduce-deadline-scheduler` receives named but not prematurely implemented contracts:

- ordered validated unscheduled task candidates;
- normalized estimates and confidence;
- dependencies and phase order;
- work type and essential/optional/stretch classification;
- fallback mode and split points or multi-session boundaries;
- low-calibration flag and trace facts;
- pass-through deadline, deadline type, capacity, rest/unavailable dates, buffer policy, and existing-plan context.

The current change preserves downstream ownership:

- final scheduled dates;
- date-window construction;
- capacity and existing-load fit math;
- buffer reservation and erosion;
- continuation-session date placement;
- schedule risk report;
- infeasibility option mapping and deterministic effects;
- `reduce_scope`/`lower_depth` fit math;
- `infeasible_review`.

## Scope Drift Review

No scope drift found.

- Compiler fixtures are explicitly unscheduled and cannot include capacity-gap math, buffer erosion, overloaded dates, or `infeasible_review`.
- Sensitive-content rules limit source usage to submitted or selected content and shallow upstream facts; they do not introduce broad local ingestion.
- Draft persistence remains the owner of physical storage and activation transactions.
- Scheduler remains the owner of dates and feasibility math.
- UI remains downstream.

## Verification

- `openspec validate introduce-plan-compiler --strict`: passed.
- `openspec validate persist-intake-plan-drafts --strict`: passed.
- `openspec validate introduce-deadline-scheduler --strict`: passed.
- `openspec status --change introduce-plan-compiler --json`: proposal, design, specs, and tasks present.

## Decision

Passed. `introduce-plan-compiler` is ready to advance to `apply` planning on a later heartbeat. The change has three scope-aware product-deepen records, satisfies upstream draft persistence handoff requirements, names downstream scheduler contracts without implementing them, and has no unresolved scope drift or design contradiction.
