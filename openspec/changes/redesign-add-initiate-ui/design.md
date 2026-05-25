## Scope

This change implements the user-facing Add / Initiate flow after backend contracts exist.

Included:

- Add / Initiate tab structure;
- input surface for first-version item types;
- role review UI;
- existing-plan attachment review UI;
- anchor review UI;
- async progress rendering;
- needs-input, compile-failed, infeasible-review, draft-review, activation-failure states;
- summary-first draft review;
- option selection for infeasible drafts;
- activation, cancel, retry, edit controls;
- Today/noise exclusion in the UI.

Excluded:

- router implementation;
- compiler implementation;
- scheduler implementation;
- physical data migration;
- automatic Obsidian sync;
- deep GitHub/source viewer.

## User Flow

1. User opens Add / Initiate.
2. User submits text, URL, GitHub repo, note snippet, existing project item, interview prep item, or resume/project material.
3. UI starts async intake session and subscribes to progress.
4. UI shows role recommendation and low-cost confirmation.
5. If non-plan, UI offers store/attach/cancel and exits without Today noise.
6. If plan-generating, UI shows anchors: deadline, capacity, target output, target depth, assumptions.
7. UI shows compile/schedule progress.
8. UI shows draft review, infeasible review, needs input, or compile failure.
9. User activates, edits, retries, stores for later, or cancels.

## Role Review

Role review shows:

- recommended role;
- confidence;
- short reason;
- role switch controls;
- existing-plan selector when needed;
- attachment mode choices for existing plans.

User-facing "supporting material" maps to `attach_to_existing_plan` plus `material_only`.

## Anchor Review

Anchor review shows:

- deadline and deadline type;
- available time/capacity;
- target output;
- target depth;
- accepted assumptions.

Missing deadline for a planning item requires a deadline/timebox or storage for later. The UI should not start a fake active plan without a deadline.

## Progress States

Add / Initiate progress can show:

- analyzing input;
- routing item;
- previewing source;
- generating phases;
- generating tasks;
- validating tasks;
- scheduling;
- preparing review.

Terminal/review states:

- `role_review`;
- `needs_input`;
- `compile_failed`;
- `infeasible_review`;
- `draft_ready`;
- `stored_non_plan`;
- `error`.

Processing states must never be displayed as created Today tasks.

## Draft Review

Draft review is summary-first:

- role and target output;
- deadline fit;
- key assumptions;
- first-week schedule;
- buffer summary;
- low-energy fallback summary;
- capacity/deadline risk;
- primary confirmation action.

Full schedule, source details, and per-task edits remain behind explicit expansion controls.

## Infeasible Review

Infeasible review shows concrete facts first:

- capacity gap;
- overloaded dates;
- expected-late work;
- buffer erosion;
- low calibration.

Options use canonical ids, localized labels, and explicit effects. Hard deadlines must not show `accept_late_finish`.

## Activation And Cancellation

Activation calls the confirmation surface for the latest draft version. If activation fails, the UI keeps the draft intact and offers retry, edit, or cancel.

Cancelling before activation creates no active tasks. The user can discard or store as later/reference when appropriate.

## Noise Boundaries

The UI must not show unconfirmed draft tasks in Today or active Calendar. Non-plan entries should not create badges, deadline-risk alerts, smart-mode proposal triggers, or reminder surfaces.
