## Why

After routing, draft persistence, compiler, and scheduler surfaces exist, the user still needs a low-maintenance Add / Initiate experience that does not feel like another system to maintain. The UI must support submitting goals/resources, confirming role and anchors, watching async progress, reviewing draft plans, handling infeasible states, and activating or cancelling without leaking tasks into Today.

This change is the fifth split from `redesign-study-intake-planning`. It owns the front-end experience and Add / Initiate progress contract. It does not implement routing, compilation, scheduling, or data persistence internals.

## What Changes

- Rename/restructure the Add tab into Add / Initiate.
- Support input UI for text goals, URLs, GitHub repos, existing project snippets, interview prep items, resume/project notes, and note snippets.
- Build role confirmation UI with recommended role, reason, confidence, and role switching.
- Build anchor confirmation UI for deadline, available time, target output, target depth, and assumptions.
- Show async progress stages for routing, preview, phase/task generation, validation, scheduling, and review preparation.
- Show summary-first draft review: role, assumptions, deadline fit, first-week schedule, buffer, fallback, risk, and primary action.
- Show infeasible review choices using canonical option ids.
- Keep unconfirmed drafts and non-plan items out of Today and active Calendar views.
- Preserve draft on activation failure and support retry/edit/cancel.

## Capabilities

### Affected Specs

- `assistant-panel-ui`
- `ingestion-progress-sse`
- `study-intake-planning`

### Modified Capabilities

- `assistant-panel-ui`: Add / Initiate UI and draft review experience.
- `ingestion-progress-sse`: Add / Initiate progress stages and terminal/review states.

### New Capability Usage

- `study-intake-planning`: user-visible draft review, activation, cancellation, async recovery, and noise boundaries.

## Impact

- Future frontend/ViewModel: Add / Initiate tab, role/anchor review, progress state rendering, draft review, infeasible options, activation/cancel/retry flows.
- Future backend integration: UI calls router, compiler/scheduler, activation, and progress stream surfaces created by prior child changes.
