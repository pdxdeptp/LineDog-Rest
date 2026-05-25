# Product Deepen Round 1: redesign-add-initiate-ui

- Automation: add-initiate-changes
- Checkpoint: redesign-add-initiate-ui:product_deepen_round_1
- Result: completed
- Completed at: 2026-05-25T12:48:42Z

## Change Understanding

This change turns the completed Add / Initiate backend primitives into a user-facing flow: submit an item, confirm its role, confirm planning anchors, watch progress, review a draft or infeasible state, and activate/store/cancel without leaking unconfirmed tasks into Today.

Round 1 found a P0 implementation gap: the docs described a smooth Add / Initiate session, but they did not say what API/session contract lets Swift move from route review to anchor review, compiler, scheduler, options, and activation. Existing backend helpers and endpoints are intentionally split by earlier changes; the UI worker would otherwise have to guess orchestration.

The boundary remains clear after this round: this change may add a thin orchestration/progress adapter that wraps completed helpers, but it must not reimplement routing heuristics, compiler task generation, scheduler math, draft persistence semantics, or activation guards.

## Adjacent Changes Read

Upstream `introduce-deadline-scheduler`:

- Provides review-only scheduler statuses, scheduled days, risk report, fallback metadata, canonical option ids, option effects, and no-Today/no-activation boundary.
- Does not expose Add / Initiate UI, localized labels, activation UI, or progress rendering.

Previous upstream contracts:

- `introduce-study-intake-router` provides `/api/study-intake/route` and `/api/study-intake/confirm`.
- `persist-intake-plan-drafts` provides durable draft shells, versions, activation guards, and storage/non-plan boundaries.
- `introduce-plan-compiler` provides compiler packages and recovery states.

No downstream change exists; this is the final child change before implementation is complete.

## Experience Loops

### Add / Initiate Session Loop

- Goal: Make one coherent user-facing session from the split backend primitives.
- Entry: user submits text, URL, GitHub repo, note snippet, project material, interview prep, or resume material.
- Main path: start/route session -> role review -> role confirmation -> anchor review -> compile/schedule -> review state.
- Success state: draft review, infeasible review, non-plan stored state, material attachment, or one-off exit.
- Failure state: recoverable `needs_input`, `compile_failed`, `activation_failed`, stale draft, or general error.
- Cancel/exit: cancellation before activation creates no active tasks.
- Feedback: shared stage names and session identity.
- Acceptance criteria: ViewModel and backend tests prove session id, draft id/version, stale event rejection, and no active tasks before activation.
- Coverage before this round: partial. After this round: complete enough for apply planning.

### Thin Orchestration Loop

- Goal: Let UI call completed helpers through a product boundary instead of stitching private implementation details.
- Entry: route, confirm role, confirm anchors, apply option, activate.
- Main path: adapter calls router/draft/compiler/scheduler/activation helper for the step and returns a typed review state.
- Success state: canonical review/terminal payload.
- Failure state: helper failure is surfaced as recoverable UI state without mutation when possible.
- Cancel/exit: adapter preserves draft/non-plan boundary.
- Feedback: progress event or locally derived stage uses the same stage names.
- Acceptance criteria: adapter adds no new core routing/compiler/scheduler/activation behavior.
- Coverage before this round: missing. After this round: added to proposal, design, specs, and tasks.

## Deep Issues

### P0: Missing End-To-End Orchestration Contract

- Problem: UI docs referenced route, compiler, scheduler, activation, and progress as if they were one surface, but no product contract connected them.
- Why it matters: apply workers could either call legacy URL ingestion, duplicate backend logic in Swift, or invent a new backend surface that violates previous child-change boundaries.
- Fix applied: Added an explicit thin Add / Initiate orchestration/progress adapter contract with session identity, route review, role confirmation, anchor confirmation, option effects, activation, and terminal storage states.
- Destination: proposal, design, ingestion-progress-sse spec, assistant-panel-ui spec, study-intake-planning spec, tasks.
- Scope impact: In scope as integration glue. It does not add routing heuristics, task generation, scheduling math, or activation semantics.

### P0: Legacy URL Ingestion Could Be Mistaken For Add / Initiate

- Problem: current app already has URL-only ingestion/study-plan UI surfaces; the OpenSpec did not explicitly prevent workers from using those as the implementation path.
- Why it matters: that would collapse the redesign back into parser/resource ingestion and miss text goals, repo roles, existing-plan attachments, and non-plan storage.
- Fix applied: Added legacy compatibility language: old URL ingestion remains available, but Add / Initiate must not call it as the primary implementation path.
- Destination: design, ingestion-progress-sse spec, tasks.
- Scope impact: In scope. It protects the first-version boundary without deleting legacy compatibility code.

## Product Model Review

Concepts clarified:

- Add / Initiate session;
- stage;
- review state;
- draft id/version;
- orchestration adapter;
- terminal storage state.

Defaults and hidden assumptions:

- Progress may be server-streamed or locally derived for synchronous substeps, but stage names and draft safety must remain identical.
- `createsActiveTasks=false` is a session invariant until activation succeeds.

## Scope Decisions

In scope:

- thin orchestration/progress adapter;
- Swift API models for session/review state;
- ViewModel state machine using session id and draft version;
- progress rendering for the shared stage contract.

Out of scope:

- new routing heuristics;
- new compiler prompts or task generation rules;
- new scheduler math;
- physical data migration;
- automatic Obsidian sync;
- deep GitHub/source viewer.

Deferred upstream dependencies:

- none blocking after this round. Completed upstream helpers are available; this change wraps them.

Downstream contracts preserved:

- none, because this is the final child change. It preserves active-task boundaries for Today, Calendar, adjustment, and smart-mode surfaces.

## Recommended Next Actions

Must address before apply:

- Continue product-deepen with UI state/recovery details and noise/test boundaries.

Needs user scope decision:

- None in this round.

Future proposals:

- Rich source viewer, automatic Obsidian sync, and deeper GitHub browsing remain future work.
