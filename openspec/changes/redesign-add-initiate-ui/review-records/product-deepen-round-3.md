# Product Deepen Round 3: redesign-add-initiate-ui

- Automation: add-initiate-changes
- Checkpoint: redesign-add-initiate-ui:product_deepen_round_3
- Result: completed
- Completed at: 2026-05-25T12:48:42Z

## Change Understanding

Rounds 1 and 2 made the UI integration and state model implementable. Round 3 checked the two places a first implementation could still betray the product goal: making the draft review too noisy, and letting unconfirmed drafts/materials leak into Today, Calendar, smart-mode, or reminders.

This change should make Add / Initiate feel like a low-maintenance plan review surface. It should not become a second task inbox.

## Adjacent Changes Read

Upstream scheduler:

- Supplies scheduled days, load states, buffer facts, fallback metadata, risk report, and canonical option ids.
- Requires overload and buffer risk to remain visible after acceptance.
- Treats fallback as review metadata, not completion.

Upstream draft persistence and activation:

- Active tasks are created only after latest-version activation.
- Non-plan and material-only items remain outside active schedules.

No downstream change exists.

## Experience Loops

### Summary-First Draft Review Loop

- Goal: let the user quickly decide whether the plan is reasonable without reading every task.
- Entry: `draft_review` package arrives.
- Main path: compact summary -> expand schedule/source/edits only if needed -> activate/edit/store/cancel.
- Success state: user understands deadline fit, first week, buffer, fallback, and risk.
- Failure state: UI floods the user with every item or hides important risk facts.
- Cancel/exit: cancel or store before activation.
- Feedback: first-week day rows, buffer/risk badges, one primary action.
- Acceptance criteria: first-week summary is derived from scheduled review data and full details remain behind expansion.
- Coverage before this round: partial. After this round: complete.

### Quiet Boundary Loop

- Goal: prevent add-time submissions from becoming task noise.
- Entry: any route, review, storage, attachment, cancellation, option, or activation state.
- Main path: only activation success refreshes active learning surfaces.
- Success state: Today and Calendar show confirmed active tasks only.
- Failure state: draft tasks, references, later resources, material-only attachments, or fallback modes create badges/reminders/proposals.
- Cancel/exit: storage/cancel states remain quiet.
- Feedback: terminal state can refresh relevant material/resource list only.
- Acceptance criteria: tests/manual QA prove no Today, Calendar, smart-mode, or reminder noise before activation.
- Coverage before this round: partial. After this round: complete.

## Deep Issues

### P0: Draft Review Could Become Another Noisy Task List

- Problem: docs said "summary-first" but did not define what appears in the first view.
- Why it matters: workers could render every scheduled item by default, recreating the maintenance burden the feature is supposed to remove.
- Fix applied: Defined compact summary fields, first-seven-day window, day-row contents, buffer/fallback/risk facts, and expansion boundary.
- Destination: design, assistant-panel-ui spec, study-intake-planning spec, tasks.
- Scope impact: In scope; this is the core UI review experience.

### P0: Fallback Metadata Could Become Extra Todos

- Problem: fallback was listed in review but not explicitly prohibited from becoming a separate task.
- Why it matters: low-energy fallback is meant to reduce friction, not create a noisy second schedule or falsely complete normal work.
- Fix applied: Added fallback rendering as alternate execution metadata, not a separate Today task or normal completion.
- Destination: design, assistant-panel-ui spec, tasks.
- Scope impact: In scope; preserves scheduler and active-task semantics.

### P0: Active-Surface Refresh Boundary Needed Precision

- Problem: "keep out of Today" existed, but it did not define refresh behavior across storage, attachment, option effects, cancellation, activation failure, or activation success.
- Why it matters: smart-mode proposals, deadline alerts, calendar load, or Today badges could still fire from unconfirmed drafts or stored material.
- Fix applied: Added refresh rules and quiet-boundary scenarios/tasks.
- Destination: design, assistant-panel-ui spec, study-intake-planning spec, tasks.
- Scope impact: In scope.

### P1: Real-Context QA Needed To Cover The Actual User Inputs

- Problem: manual QA listed examples but not their product roles or expected states.
- Why it matters: implementation could pass generic tests while missing GitHub repo rebuilds, recurring practice, existing project material, or quiet reference storage.
- Fix applied: Added real-context QA matrix with expected flow shapes.
- Destination: design, tasks.
- Scope impact: In scope as verification, not new feature logic.

## Product Model Review

Concepts clarified:

- compact draft summary;
- first-week schedule window;
- fallback as alternate execution metadata;
- active-surface refresh contract;
- real-context QA matrix.

Hidden assumptions closed:

- accepted overload and accepted buffer risk remain visible;
- stored/reference/material-only states may update material lists but not active surfaces;
- legacy URL ingestion remains compatibility coverage, not the Add / Initiate acceptance path.

## Scope Decisions

In scope:

- summary-first schedule review rendering;
- localized option labels from canonical ids;
- fallback as alternate execution metadata;
- quiet no-Today/no-Calendar/no-smart-mode boundaries;
- real-context QA fixtures/manual verification.

Out of scope:

- advanced drag-and-drop schedule editing during Add / Initiate;
- full source/GitHub viewer;
- automatic Obsidian sync;
- new smart-mode proposal logic;
- changing active Calendar/Today data models beyond refresh behavior.

Deferred upstream dependencies:

- none blocking. Completed scheduler/draft contracts provide the facts needed for summary and noise boundaries.

Downstream contracts preserved:

- none, final child change. Active Today, Calendar, adjustment, and smart-mode consumers continue to read confirmed active plans only.

## Recommended Next Actions

Must address before apply:

- Run `scope_dependency_check` on the next heartbeat. It should verify all three product-deepen records include scope decisions and that the UI change has not absorbed core router/compiler/scheduler logic beyond the thin orchestration adapter.

Needs user scope decision:

- None.

Future proposals:

- rich per-task schedule editor, source viewer, Obsidian sync, and advanced option explanations.
