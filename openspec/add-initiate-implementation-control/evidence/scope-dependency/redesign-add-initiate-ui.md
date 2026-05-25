# Scope Dependency Check: redesign-add-initiate-ui

- Automation: add-initiate-changes
- Checkpoint: redesign-add-initiate-ui:scope_dependency_check
- Result: passed
- Completed at: 2026-05-25T13:00:12Z
- Current change: redesign-add-initiate-ui
- Upstream change: introduce-deadline-scheduler
- Downstream change: none; this is the final Add / Initiate child change

## Evidence Read

Current change:

- `openspec/changes/redesign-add-initiate-ui/proposal.md`
- `openspec/changes/redesign-add-initiate-ui/design.md`
- `openspec/changes/redesign-add-initiate-ui/specs/assistant-panel-ui/spec.md`
- `openspec/changes/redesign-add-initiate-ui/specs/ingestion-progress-sse/spec.md`
- `openspec/changes/redesign-add-initiate-ui/specs/study-intake-planning/spec.md`
- `openspec/changes/redesign-add-initiate-ui/tasks.md`
- `openspec/changes/redesign-add-initiate-ui/review-records/product-deepen-round-1.md`
- `openspec/changes/redesign-add-initiate-ui/review-records/product-deepen-round-2.md`
- `openspec/changes/redesign-add-initiate-ui/review-records/product-deepen-round-3.md`

Adjacent upstream:

- `openspec/changes/introduce-deadline-scheduler/design.md`
- `openspec/changes/introduce-deadline-scheduler/specs/study-intake-planning/spec.md`
- `openspec/add-initiate-implementation-control/evidence/cross-change-contracts/introduce-deadline-scheduler-to-redesign-add-initiate-ui.md`

## Product Deepen Scope Decision Audit

All three product-deepen records include explicit scope decisions:

- Round 1 records in-scope orchestration/progress adapter, Swift API models, ViewModel state, and shared progress rendering. It excludes new routing heuristics, compiler prompts/task generation, scheduler math, data migration, Obsidian sync, and deep GitHub/source viewer work.
- Round 2 records in-scope ViewModel state machine, retry/cancel/edit/store transitions, stale response rejection, and option-effect review handling. It excludes scheduler option math, bypassing backend draft-version guards, fallback completion semantics, and pre-activation Today/Calendar changes.
- Round 3 records in-scope summary-first draft review, canonical option label rendering, fallback-as-metadata, quiet active-surface boundaries, and real-context QA. It excludes advanced schedule editing, source/GitHub viewer, Obsidian sync, new smart-mode proposal logic, and active Calendar/Today data-model changes beyond refresh behavior.

The three rounds preserved the intended boundary instead of expanding this final UI change into parser, compiler, scheduler, or priority-judgment work.

## Current Boundary

`redesign-add-initiate-ui` owns the user-facing Add / Initiate experience after upstream primitives exist:

- Add / Initiate entry, input, role review, existing-plan attachment review, anchor review, progress rendering, draft/infeasible/needs-input/compile-failed review states, activation/cancel/retry/edit/store UI, and quiet active-surface behavior.
- A thin Add / Initiate orchestration/progress adapter is in scope only as integration glue so Swift sees one coherent session contract.
- The adapter may call completed router, draft persistence, compiler, scheduler, option-effect, storage, and activation helpers, but it must not add routing heuristics, generate tasks, change scheduler math, bypass draft version guards, or create active work before explicit activation.

This boundary is coherent and independently shippable as the final surface over the four completed upstream changes.

## Upstream Contract Check

The upstream scheduler contract is satisfied and available:

- It returns review-only `ScheduledDraftReview` packages with `draft_review`, `infeasible_review`, and `needs_input` statuses.
- It passes through compiler recovery states such as `needs_input` and `compile_failed`.
- It provides `scheduled_days`, scheduled item metadata, fallback metadata, `unscheduled_tasks`, risk facts, assumptions, scheduler trace, and canonical infeasibility options.
- It does not activate tasks, create Today actions, mutate compiler packages, localize labels, render UI, or refresh active surfaces.

The current UI change consumes those facts for rendering and user confirmation. It does not take ownership of scheduler placement, capacity math, scope/depth recomputation, or option-effect algorithms.

Earlier upstream contracts remain preserved:

- Router owns role recommendation, confirmation, source preview, and initial role/material routing.
- Draft persistence owns durable draft identity, versions, activation guards, storage states, and non-plan boundaries.
- Compiler owns phase/task generation, validation, estimate facts, recovery packages, and compiler-recompute handoffs.
- Scheduler owns date placement, capacity/buffer/risk facts, infeasibility option availability, and deterministic option effects.

No deferred upstream dependency blocks apply. The only implementation caution is to keep task group 0 focused on typed adapter wiring and contract tests, not new planner logic.

## Downstream Contract Check

There is no downstream child change. This change must preserve existing active-surface consumers:

- Today, active Calendar, adjustment flows, and smart-mode proposals continue to read confirmed active plans only.
- Non-plan storage, later/reference resources, material-only attachments, cancelled sessions, activation failures, draft reviews, infeasible reviews, and option-effect progress must not refresh active work surfaces.
- Activation success is the only Add / Initiate state that refreshes Home, Today, project overview, active Calendar facts, and smart-mode proposal context as active work.

## Scope Drift Decision

Decision: KEEP CURRENT SCOPE.

The current change is large but still one coherent final surface because the backend child changes have already split routing, persistence, compilation, and scheduling. Splitting the UI further before apply would likely create more coordination overhead than risk reduction.

The potentially suspicious item is the backend/API orchestration adapter. It remains acceptable inside this change because it is explicitly constrained to product glue, session identity, progress mapping, and wrapper calls over completed helpers. Apply planning should split it as an early contract/test group and reject any implementation that adds new core routing, compiler, scheduler, or activation behavior.

## Verification

Commands passed:

- `openspec validate redesign-add-initiate-ui --strict`: valid.
- `openspec validate introduce-deadline-scheduler --strict`: valid.
