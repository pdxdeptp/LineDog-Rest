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
- Today/noise exclusion in the UI;
- a thin Add / Initiate orchestration/progress adapter that exposes the completed backend helpers as a coherent user-facing session.

Excluded:

- router implementation;
- compiler implementation;
- scheduler implementation;
- physical data migration;
- automatic Obsidian sync;
- deep GitHub/source viewer.

The orchestration adapter is in scope only as glue. It may call completed router,
draft persistence, compiler, scheduler, and activation helpers and expose their
state to Swift. It must not create new routing heuristics, generate phases/tasks,
change scheduler math, bypass draft version guards, or write active tasks before
explicit activation.

## Integration Contract

Add / Initiate must have one coherent session contract instead of forcing the
Swift UI to stitch unrelated legacy endpoints together.

The first-version backend adapter exposes:

- start/route session: accepts `clientRequestId`, raw input, source type, optional user hint, and optional existing-plan target; returns `sessionId`, `intakeItemId`, recommended role, confidence, reasons, next action, and `createsActiveTasks=false`;
- role confirmation: accepts confirmed role, title, URL when present, existing plan id, attachment mode, canonical repo role, and metadata; returns stored non-plan, material-only attachment, or draft handoff;
- anchor confirmation: accepts draft id or intake id plus deadline, deadline type, capacity, target output, target depth, assumptions, rest/unavailable dates, buffer policy, and load shape; calls completed compiler and scheduler helpers and returns `needs_input`, `compile_failed`, `infeasible_review`, or `draft_review`;
- option effect: accepts a draft id/version plus canonical option id and parameters; calls completed scheduler/compiler/storage effects and returns a new review package, storage state, or compiler-recompute handoff;
- activation: calls the existing latest-version activation guard and returns success or a recoverable activation/stale-draft failure.

The UI may keep using existing stable endpoints under the adapter, but the
ViewModel must treat the adapter contract above as the product boundary.
Legacy URL ingestion remains a compatibility path and is not the Add / Initiate
implementation path.

## Session And Progress Contract

Each Add / Initiate session has:

- `sessionId`;
- `clientRequestId`;
- optional `intakeItemId`;
- optional `draftId`;
- optional `draftVersion`;
- `stage`;
- `reviewState`;
- `createsActiveTasks=false` until activation succeeds.

Progress stages are emitted or derived in this order when applicable:

1. `analyzing_input`
2. `routing_item`
3. `previewing_source`
4. `role_review`
5. `anchor_review`
6. `generating_phases`
7. `generating_tasks`
8. `validating_tasks`
9. `scheduling`
10. `preparing_review`
11. terminal/review state

Terminal/review states are:

- `stored_non_plan`;
- `material_attached`;
- `needs_input`;
- `compile_failed`;
- `infeasible_review`;
- `draft_review`;
- `activation_failed`;
- `activated`;
- `cancelled`;
- `error`.

The progress adapter should buffer enough recent events for a reconnecting
client to render the current session state. If a durable backend event stream is
not available for a short synchronous step, the ViewModel may derive the stage
locally, but it must still use the same stage names and must not display derived
progress as created tasks.

## UI State Machine

The ViewModel should model Add / Initiate as one state machine, not as separate
booleans for every card.

States:

- `idle_input`: user can enter or paste an item.
- `routing_progress`: route request in flight.
- `role_review`: recommended role, confidence, reason, and role-switch controls visible.
- `non_plan_terminal`: reference/later/one-off stored, or material-only attached.
- `anchor_review`: plan-generating path needs deadline, capacity, target output, target depth, and accepted assumptions.
- `planning_progress`: preview/compiler/scheduler work in flight with stage feedback.
- `needs_input`: one focused question from router, compiler, or scheduler; existing answers and anchors remain editable.
- `compile_failed`: generation/validation failed; user can retry, simplify input, store for later, or cancel.
- `infeasible_review`: concrete scheduler facts and canonical option choices visible.
- `draft_review`: summary-first schedule review visible and activation enabled only for latest draft version.
- `option_effect_progress`: a selected option effect is being applied and the old draft remains visible until a new review state returns.
- `activation_progress`: latest draft/version activation in flight.
- `activation_failed`: current draft remains intact with retry, edit, store, or cancel actions.
- `activated`: active-plan creation succeeded; Home, Today, project overview, and calendar refresh.
- `cancelled`: local session exits without creating active work.

Every review state has exactly one primary action and secondary text/icon
actions. The primary action should never be "confirm" when the state still needs
input, a tradeoff choice, or a newer draft version.

## Recovery Rules

- `needs_input` asks at most one focused question and returns to planning progress after the user answers.
- `compile_failed` keeps the submitted input, role, and anchors so retry does not require starting over.
- `infeasible_review` option selection returns a new review package, storage state, or compiler-recompute handoff before activation.
- `activation_failed` preserves draft id/version and scheduled review data.
- Stale draft activation must be blocked; UI reloads or requests the latest review before allowing activation.
- Cancel before activation creates no active tasks. It may discard the session or store the item as later/reference when the current role permits that.
- Retry must be idempotent by session/draft identity. A late response from an older retry cannot overwrite a newer state.

## User Flow

1. User opens Add / Initiate.
2. User submits text, URL, GitHub repo, note snippet, existing project item, interview prep item, or resume/project material.
3. UI starts an Add / Initiate session and subscribes to progress or derives the same stage contract for synchronous substeps.
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
- `draft_review`;
- `stored_non_plan`;
- `material_attached`;
- `activation_failed`;
- `activated`;
- `cancelled`;
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

The compact summary uses scheduler facts directly:

- deadline fit from review status and risk report;
- first-week schedule from the first seven calendar days in `scheduled_days`, or the full window if shorter;
- day rows show date, planned minutes, load state, and the highest-risk visible item/fallback cue;
- buffer summary shows reserved buffer days and buffer erosion when present;
- fallback summary names fallback output and risk effect without presenting it as a separate todo;
- capacity risk shows essential work minutes, available execution capacity, capacity gap, overloaded dates, expected-late tasks, and existing-load conflicts when present.

The UI should not render every scheduled item by default. It starts with a
reviewable summary, then lets the user expand full schedule, source details, and
per-task edits.

## Infeasible Review

Infeasible review shows concrete facts first:

- capacity gap;
- overloaded dates;
- expected-late work;
- buffer erosion;
- low calibration.

Options use canonical ids, localized labels, and explicit effects. Hard deadlines must not show `accept_late_finish`.

Option labels are display-only translations of canonical ids:

- `reduce_scope`: reduce optional/stretch work while preserving target output/depth;
- `lower_depth`: choose a shallower target depth and regenerate;
- `extend_deadline`: change deadline and reschedule;
- `increase_capacity`: add available time and reschedule;
- `accept_crunch`: use more of available capacity without exceeding it;
- `accept_buffer_risk`: consume reserved buffer while keeping risk visible;
- `accept_overload`: explicitly accept overloaded dates;
- `answer_one_question`: answer the missing/low-calibration question;
- `edit_estimates`: adjust estimates and reschedule;
- `accept_rough_draft`: keep visible assumptions and continue;
- `accept_late_finish`: allow late finish only for soft or assumed deadlines;
- `store_for_later`: exit active planning without active tasks.

## Activation And Cancellation

Activation calls the confirmation surface for the latest draft version. If activation fails, the UI keeps the draft intact and offers retry, edit, or cancel.

Cancelling before activation creates no active tasks. The user can discard or store as later/reference when appropriate.

## Noise Boundaries

The UI must not show unconfirmed draft tasks in Today or active Calendar. Non-plan entries should not create badges, deadline-risk alerts, smart-mode proposal triggers, or reminder surfaces.

Refresh behavior:

- route review, role confirmation, anchor review, progress, `needs_input`, `compile_failed`, `infeasible_review`, and `draft_review` do not refresh Today as if work exists;
- `stored_non_plan`, `material_attached`, and `cancelled` may refresh only the relevant material/resource list, not Today or active Calendar load;
- option effects refresh only the current draft review state until activation succeeds;
- activation success refreshes Home, Today, project overview, active Calendar facts, and smart-mode proposal context;
- activation failure preserves the draft and does not refresh active surfaces.

## Real-Context QA Matrix

Manual QA and fixture coverage should use the user's actual planning shapes:

- AgentGuide or similar finite learning project: role review -> anchor review -> feasible draft summary.
- easyagent repo rebuild/source understanding: GitHub repo as main learning object or clone/rebuild target -> infeasible review with hard-deadline guardrails.
- LeetCode cadence: recurring practice source -> first-week schedule and no source-structure mirroring.
- agent/backend interview prep: topic review cycle -> target-depth and output visible.
- resume/project rewrite: project packaging -> feasible packaging dry run and activation refresh.
- existing MalDaze project material: attach-to-existing-plan with `material_only`, `draft_phase`, and `scheduled_work` paths.
- reference/later item: storage terminal state with no Today badges or smart-mode proposals.

The old URL-only ingestion UI remains compatibility coverage, not the Add /
Initiate acceptance path.
