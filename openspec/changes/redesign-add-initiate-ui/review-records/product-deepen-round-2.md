# Product Deepen Round 2: redesign-add-initiate-ui

- Automation: add-initiate-changes
- Checkpoint: redesign-add-initiate-ui:product_deepen_round_2
- Result: completed
- Completed at: 2026-05-25T12:48:42Z

## Change Understanding

Round 1 made the integration surface implementable. Round 2 challenged the interaction model itself: if the UI is built as scattered cards and booleans, retry, option effects, stale drafts, and activation failures will become inconsistent and noisy.

The product shape should be a single Add / Initiate session state machine. This keeps the flow low-maintenance: the user sees one current review state, one primary action, and explicit secondary exits instead of a busy dashboard of half-actions.

## Adjacent Changes Read

Upstream `introduce-deadline-scheduler`:

- May return `needs_input`, `compile_failed` passthrough, `infeasible_review`, `draft_review`, storage states, or compiler-recompute handoffs.
- Requires UI to treat option effects as review recomputation, not activation.
- Requires UI to preserve hard-deadline guardrails and latest-version activation.

Upstream draft persistence:

- Provides draft version and stale activation guard semantics.
- Preserves activation failures and idempotency boundaries.

No downstream change exists.

## Experience Loops

### Review State Machine Loop

- Goal: keep Add / Initiate understandable and recoverable.
- Entry: any route/progress/review event.
- Main path: state transition with one primary action and valid secondary actions.
- Success state: `draft_review`, `infeasible_review`, stored terminal state, or activated state.
- Failure state: `needs_input`, `compile_failed`, `activation_failed`, or stale draft/version.
- Cancel/exit: `cancelled` with no active tasks before activation.
- Feedback: stage text plus stable review state.
- Acceptance criteria: ViewModel tests cover all states and stale response rejection.
- Coverage before this round: partial. After this round: complete.

### Option Effect Loop

- Goal: user chooses a concrete tradeoff without silently activating or mutating the wrong thing.
- Entry: `infeasible_review` with canonical option ids.
- Main path: select option -> option-effect progress -> new review/storage/recompute/needs-input state.
- Success state: updated review package or safe terminal state.
- Failure state: option effect fails; old review package remains visible.
- Cancel/exit: user cancels or stores for later before activation.
- Feedback: concrete fact and option effect label.
- Acceptance criteria: UI does not show activation until a latest review package is returned.
- Coverage before this round: missing. After this round: added to design/spec/tasks.

## Deep Issues

### P0: Missing Add / Initiate State Machine

- Problem: docs listed states but did not define legal transitions, primary actions, stale response handling, or how recoverable failures preserve context.
- Why it matters: workers could build a fragile UI where old async responses overwrite newer drafts, activation is offered from a blocked state, or retry forces a restart.
- Fix applied: Added a single ViewModel state machine with named states from `idle_input` through `activated`/`cancelled`.
- Destination: design, assistant-panel-ui spec, tasks.
- Scope impact: In scope. This is UI/ViewModel behavior, not backend algorithm work.

### P0: Option Effects Were Underspecified

- Problem: infeasible options were named, but the UI did not clearly treat them as producing a new review/storage/recompute state before activation.
- Why it matters: a later worker might apply `accept_overload`, `lower_depth`, or `store_for_later` as an activation shortcut or a local UI-only mutation.
- Fix applied: Added option-effect progress and result handling requirements.
- Destination: design, assistant-panel-ui spec, study-intake-planning spec, tasks.
- Scope impact: In scope. It preserves scheduler/compiler ownership.

### P0: Stale Draft And Retry Safety Needed UI-Level Guards

- Problem: activation version guards exist upstream, but the UI also needs to ignore stale progress, retry, and option responses.
- Why it matters: a slow previous request could restore an obsolete review and let the user confirm the wrong plan.
- Fix applied: Added stale session/draft-version response rejection and latest-version activation scenarios.
- Destination: design, assistant-panel-ui spec, study-intake-planning spec, tasks.
- Scope impact: In scope.

## Product Model Review

Concepts clarified:

- one Add / Initiate state machine;
- one primary action per review state;
- option effect as a transition, not activation;
- stale session/draft-version rejection.

Hidden assumptions closed:

- `needs_input` preserves context and asks only one focused question.
- `compile_failed` keeps input, role, anchors, and assumptions.
- activation failure preserves the draft package.

## Scope Decisions

In scope:

- ViewModel state machine;
- state-specific UI;
- retry/cancel/edit/store transitions;
- stale response rejection;
- option-effect progress and result handling.

Out of scope:

- implementing scheduler option math in Swift;
- bypassing backend draft-version activation guards;
- turning fallback work into completion behavior;
- changing Today/Calendar behavior before activation.

Deferred upstream dependencies:

- none blocking; upstream already owns scheduler option effects and activation guards.

Downstream contracts preserved:

- none, final child change. It preserves Today, Calendar, adjustment, and smart-mode boundaries.

## Recommended Next Actions

Must address before apply:

- Final product-deepen should check noise boundaries, UI summary payload details, and real-context QA coverage.

Needs user scope decision:

- None.

Future proposals:

- richer option explanation copy and advanced schedule editing can remain future work unless needed by first apply.
