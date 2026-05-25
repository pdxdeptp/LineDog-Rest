# Scope Dependency Check: introduce-deadline-scheduler

- Timestamp: 2026-05-25T11:09:11Z
- Change: introduce-deadline-scheduler
- Checkpoint: introduce-deadline-scheduler:scope_dependency_check
- Result: passed
- Next checkpoint: introduce-deadline-scheduler:apply

## Current Change Artifacts Read

- `openspec/changes/introduce-deadline-scheduler/proposal.md`
- `openspec/changes/introduce-deadline-scheduler/design.md`
- `openspec/changes/introduce-deadline-scheduler/specs/study-intake-planning/spec.md`
- `openspec/changes/introduce-deadline-scheduler/tasks.md`
- `openspec/changes/introduce-deadline-scheduler/review-records/product-deepen-round-1.md`
- `openspec/changes/introduce-deadline-scheduler/review-records/product-deepen-round-2.md`
- `openspec/changes/introduce-deadline-scheduler/review-records/product-deepen-round-3.md`

## Upstream Change Artifacts Read

- `openspec/changes/introduce-plan-compiler/design.md`
- `openspec/changes/introduce-plan-compiler/specs/study-intake-planning/spec.md`
- `openspec/changes/introduce-plan-compiler/tasks.md`
- `openspec/add-initiate-implementation-control/evidence/cross-change-contracts/introduce-plan-compiler-to-introduce-deadline-scheduler.md`

## Downstream Change Artifacts Read

- `openspec/changes/redesign-add-initiate-ui/proposal.md`
- `openspec/changes/redesign-add-initiate-ui/design.md`
- `openspec/changes/redesign-add-initiate-ui/specs/study-intake-planning/spec.md`
- `openspec/changes/redesign-add-initiate-ui/tasks.md`

## Product-Deepen Record Audit

All three product-deepen records contain explicit scope decisions and adjacent-change reasoning:

- Round 1 records in-scope scheduler review output, status derivation, date/capacity rules, continuation identity, and option-effect recomputation; it excludes compiler regeneration, UI controls, active-task writes, Today creation, moving existing active tasks, and broad LLM calendar generation.
- Round 2 records in-scope deterministic buffer reservation, load-shape tie-breakers, crunch/overload semantics, fallback review metadata, and tests; it excludes runtime fallback tracking, UI fallback rendering, auto-rebalancing active tasks, and changing compiler estimates/task content.
- Round 3 records in-scope scheduler preflight, safe defaults, scheduler `needs_input`, and visible assumptions; it excludes UI input collection, compiler task regeneration, persistence conflict resolution, activation, and Today writes.

## In-Scope Responsibilities

The current change owns:

- accepting only compiler `draft_review` packages for scheduling;
- returning scheduler `needs_input` for missing deadline, invalid dates, or empty schedulable task candidates;
- defaulting safe scheduler anchors such as start date, deadline type, daily capacity, active load, rest/unavailable dates, and buffer policy with visible assumptions;
- constructing inclusive local date windows;
- computing raw, existing-load, usable, planning-budget, reserved-buffer, and execution-budget capacity;
- deterministic buffer reservation and buffer erosion reporting;
- balanced, front-loaded, and light-start placement with deterministic tie-breakers;
- essential-before-optional placement while preserving dependencies;
- continuation-session splitting only at compiler-approved split points or multi-session boundaries;
- risk reporting for essential capacity gap, optional unscheduled minutes, expected-late work, overload, buffer erosion, rough estimates, and existing-load conflicts;
- canonical infeasibility option ids and deterministic option effects as review recomputation, storage result, or compiler-recompute handoff;
- hard-deadline guardrail excluding `accept_late_finish`;
- end-to-end dry-run fixtures for feasible resume packaging and infeasible easyagent rebuild.

## Out-Of-Scope Responsibilities

The current change explicitly does not own:

- intake routing;
- draft persistence internals or migrations;
- LLM phase/task generation;
- compiler regeneration for lower-depth or answer-one-question outcomes;
- Add / Initiate UI controls, labels, progress rendering, expansion controls, activation buttons, retry/edit/cancel controls, or localized option labels;
- active-task writes, Today actions, active Calendar effects, smart-mode proposal triggers, reminders, or activation;
- moving or rewriting existing active tasks;
- runtime fallback usage tracking or day-of rescheduling.

## Required Upstream Contracts

`introduce-plan-compiler` already provides the contracts required for scheduler apply:

- compiler statuses `draft_review`, `needs_input`, and `compile_failed`, with no scheduler-owned `infeasible_review`;
- phases and executable task candidates without final scheduled dates;
- estimates, estimate confidence/source, low-calibration flags, and trace;
- essential/optional/stretch classification;
- dependencies and phase links;
- normal mode, fallback mode, split points, and multi-session boundaries;
- target-depth obligation or reducible reason metadata;
- material refs and sensitive trace boundaries.

No unresolved upstream blocker was found. The current change correctly treats lower-depth and answer-one-question option effects as compiler-recompute handoffs instead of regenerating task candidates itself.

## Downstream Contracts Preserved

`redesign-add-initiate-ui` can rely on the scheduler to provide:

- `ScheduledDraftReview`-style review payloads with `needs_input`, `draft_review`, and `infeasible_review` statuses;
- scheduled days, daily load facts, buffer/risk summaries, fallback metadata, unscheduled tasks, and scheduler trace;
- canonical option ids for infeasible review;
- hard-deadline behavior that omits `accept_late_finish`;
- review-only output that does not create Today tasks, active Calendar entries, or active-plan effects before UI activation.

The scheduler names UI-visible states and payload facts but does not implement rendering, controls, localization, or activation.

## Deferred Dependencies

- UI/draft persistence must collect user responses for scheduler `needs_input` and activation decisions.
- Compiler must handle actual regeneration for lower-depth and answer-one-question handoffs.
- Runtime adjustment semantics for a user choosing fallback on a specific day remain a future/downstream concern.
- Active-load mutation or auto-rebalancing remains outside this change.

## Consistency Fix During Check

The scope check found and fixed two wording inconsistencies in `design.md`:

- the buffer algorithm summary now uses the deterministic `ceil(usable_days * 0.2)` formula instead of "about 20%";
- `accept_crunch` now explicitly raises selected dates only up to 100% usable capacity, while `accept_buffer_risk` returns a review version for downstream explicit confirmation.

These edits align the summary with the detailed rules already added during product deepening and do not expand scope.

## Validation Commands And Results

- `openspec validate introduce-plan-compiler --strict`: valid.
- `openspec validate introduce-deadline-scheduler --strict`: valid.
- `openspec validate redesign-add-initiate-ui --strict`: valid.

## Result

Scope dependency check passed. The change has not absorbed compiler, persistence, UI, activation, Today, or existing-active-task mutation responsibilities. It is ready to proceed to `introduce-deadline-scheduler:apply`.

