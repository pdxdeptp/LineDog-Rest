## Scope

This change creates the durable state layer for Add / Initiate plan drafts.

Included:

- draft plan state separate from active plan state;
- planning assumption persistence;
- draft schema and draft version;
- latest-version activation guard;
- activation event recording;
- fallback completion persistence;
- consistent 60-minute capacity fallback.

Excluded:

- intake role routing;
- LLM phase/task generation;
- deterministic scheduling implementation;
- Add / Initiate UI;
- full adjustment/smart-mode behavior after activation.

## Draft State Model

Draft state must not be represented as active tasks with a pending flag sprinkled through Today. A draft stores the intended plan, assumptions, and schedule facts separately until activation.

Logical persisted entities:

- `IntakeItem`: created by the router.
- `PlanDraft`: draft header, status, schema version, draft version, assumptions, and calibration.
- `DraftPhase`: generated or user-edited phase data.
- `DraftTask`: generated or user-edited task candidate and optional scheduled slices.
- `ActivationEvent`: immutable record linking intake item, draft version, assumptions, and created active tasks.

Physical table names can differ, but the logical split must hold.

This change must make the physical persistence contract explicit enough for the compiler and scheduler changes to consume later. Existing `study_project_drafts` and `study_project_draft_tasks` tables are a legacy starting point, not a complete implementation. Apply may either migrate/extend them or create replacement tables, but it must expose the following logical fields:

- draft header: `id`, `intake_item_id`, `status`, `schema_version`, `draft_version`, `latest_version`, `title`, `summary`, `calibration_level`, `created_at`, `updated_at`, optional `draft_kind`, optional `target_plan_id`, and optional `activated_resource_id`;
- assumptions: deadline fields, capacity fields, rest/unavailable day fields, target output, target depth, buffer policy, source roles, accepted/user-edited flags, and fact provenance;
- draft phases: stable phase id, title, purpose, order, completion evidence, estimate totals, and status;
- draft tasks: stable task id, phase id, order, action title, concrete output, completion criteria, estimate minutes, estimate confidence, dependencies, material/source references, normal mode, fallback mode, split points, schedule slices when provided by downstream scheduling, and status;
- activation events: intake id, draft id, activated draft version, assumption snapshot, schedule version, created resource id, created active task ids, actor/source, and timestamp.

Draft rows may store complex assumptions, task details, and schedule slices as JSON in the first implementation, as long as tests prove draft rows stay separate from active `tasks` and can be versioned, activated, discarded, and queried deterministically.

`draft_kind` distinguishes activation targets:

- `new_plan`: activation creates a new active resource/plan from the draft.
- `existing_plan_phase`: activation adds units/tasks to an existing active plan but does not create a new top-level resource.
- `existing_plan_scheduled_work`: activation adds scheduled tasks under an existing active plan.

`target_plan_id` is required for existing-plan draft kinds and must reference an active plan at draft creation and activation time. `material_only`, `reference_material`, `later_resource`, and `immediate_one_off` do not create plan drafts in this change.

## Migration And Compatibility

The current backend already has legacy `study_project_drafts` and `study_project_draft_tasks` tables. They are not sufficient for this change because they lack intake linkage, schema version, draft version, assumption provenance, activation events, and fallback completion semantics.

Apply must handle existing databases safely:

- detect whether legacy draft columns/tables already exist;
- add missing columns or create replacement companion tables idempotently;
- preserve existing draft rows instead of dropping or rewriting them destructively;
- map legacy draft status `review` to the new review status used by the implementation, normally `draft_review`;
- store unknown provenance for legacy facts that cannot be recovered;
- leave active `resources`, `units`, and `tasks` untouched during migration;
- make migration re-runnable on startup without duplicating draft versions or activation events.

If the implementation chooses companion tables instead of altering legacy tables directly, it must provide query helpers that expose the logical `PlanDraft`, `DraftPhase`, `DraftTask`, and `ActivationEvent` contracts regardless of the physical storage layout.

## Data-Layer Entry Points

This change should expose storage-level helpers or equivalent service methods so downstream compiler, scheduler, and UI changes do not manipulate tables ad hoc.

Required logical operations:

- create or load a draft shell from a router `intakeItemId`;
- save or replace the compiler package shell for a draft version;
- create a new draft version after a meaningful assumption/scope/task/schedule edit;
- update display-only metadata without creating a new version;
- fetch the latest draft package for review;
- discard a draft before activation;
- activate the latest valid draft version transactionally from activation-ready draft data;
- record fallback completion for an active task without full task completion.

These entry points may be implemented as functions, repository methods, or API handlers later, but the persistence layer must be testable without UI.

Draft shell creation is idempotent for the same intake item and draft kind while no activation has succeeded. Repeated create/load calls must return the existing draft shell instead of creating duplicate drafts. If a draft was discarded, a later retry may create a new draft only through an explicit recovery path.

## Versioning

Every meaningful edit that changes anchors, scope, task estimates, task list, or schedule creates a new `draftVersion`.

Activation must verify:

- draft exists;
- draft status is activatable;
- requested draft version is the latest activatable version;
- whether activation has already succeeded for that version before creating any active rows.

If any check fails, no active tasks are created and the draft remains reviewable.

Versioning is snapshot-based for V1. A meaningful edit creates a new draft version record or versioned snapshot instead of mutating the activatable version in place. Previous versions remain read-only and recoverable until activation or discard. Non-meaningful metadata edits, such as display-only labels, may update the draft header without creating a new version if they do not affect assumptions, phases, tasks, estimates, or schedule slices.

The latest activatable version is the highest draft version whose status is one of `draft_review`, `infeasible_review`, or another explicitly activatable review status. Versions with `needs_input`, `compile_failed`, `discarded`, or `superseded` are not activatable unless a later change explicitly defines a recovery transition.

## Assumptions And Provenance

Draft assumptions include:

- deadline and deadline type;
- daily capacity and per-date overrides when available;
- rest days and unavailable dates;
- target output;
- target depth;
- buffer policy;
- source roles;
- accepted/user-edited assumptions;
- provenance for major facts: user-provided, parsed, AI-assumed, unknown.

These assumptions are copied or linked into the activated plan so later adjustment can explain why the plan was built as it was.

Assumption provenance is required per major fact. V1 provenance values are:

- `user_provided`;
- `parsed`;
- `ai_assumed`;
- `system_default`;
- `unknown`.

The data layer must preserve both the value and provenance for deadline, capacity, target output, target depth, buffer policy, rest/unavailable days, and source roles. A draft can be saved with unknown facts if its status is `needs_input` or `compile_failed`; activatable draft versions must either have accepted values or explicit user-accepted assumptions for facts required by downstream scheduling.

## Draft And Active Separation

Draft tasks are visible only through draft review surfaces. They must not appear in:

- Today;
- active Calendar facts;
- active deadline-risk alerts;
- smart-mode proposal triggers.

After activation, confirmed active tasks become eligible for existing Today, Calendar, adjustment, and smart-mode flows.

Draft lifecycle status is part of the persisted contract:

- `anchor_review`: intake has been confirmed as plan-generating and is waiting for anchors/assumptions.
- `compiling`: a downstream compiler run is in progress.
- `needs_input`: compilation or validation needs one or more missing facts.
- `compile_failed`: compiler failed with recoverable or terminal validation errors.
- `infeasible_review`: compiler/scheduler produced a draft that needs user choice because constraints are infeasible.
- `draft_review`: a draft package is ready for user review.
- `activating`: activation transaction is in progress.
- `active_plan`: activation succeeded and active tasks/resource were created.
- `discarded`: user cancelled before activation.
- `stored_non_plan`: item exited planning as non-plan storage.

This change persists and transitions these statuses but does not implement compiler, scheduler, or UI behavior that decides when to enter every status.

Allowed V1 transitions:

- `anchor_review` -> `compiling`
- `compiling` -> `needs_input`
- `compiling` -> `compile_failed`
- `compiling` -> `draft_review`
- `compiling` -> `infeasible_review`
- `needs_input` -> `anchor_review`
- `compile_failed` -> `anchor_review`
- `infeasible_review` -> `draft_review`
- `draft_review` -> `activating`
- `activating` -> `active_plan`
- any pre-activation state -> `discarded`
- reference/later/material-only paths -> `stored_non_plan`

Invalid transitions must fail without creating active task rows. This change does not need to implement user-facing recovery copy, but it must preserve enough status/error data for downstream UI to show a recovery path.

## Activation Boundary

Activation is a guarded data-layer transaction, not a scheduler. This change may create active `resources`, `units`, and `tasks` only from a provided, already persisted activatable draft version. It must not generate phases, estimates, or dates during activation. If a draft task does not already include activation-ready task data and schedule slices, activation must fail safely before active task rows are inserted.

The activation transaction must:

1. load the requested draft id and version;
2. verify status is activatable and version is the latest activatable version;
3. resolve whether the version already has a successful activation event before creating any active rows;
4. verify `target_plan_id` is still active when the draft kind targets an existing plan;
5. create or promote active plan/task rows from the provided draft payload;
6. write an immutable activation event;
7. mark the draft version as activated and link `activated_resource_id` or target plan.

The transaction must roll back entirely if any step fails.

Activation retry behavior is idempotency-safe. A duplicate activation request for a draft version that already has a successful activation event must not create a second active resource or duplicate tasks. It may return the existing activation event or reject with an `already_activated` status, but the result must be non-destructive.

Discard after activation is invalid. Once a draft reaches `active_plan`, discard/cancel operations must not delete or mutate active plan rows; later adjustment changes are outside this change.

## Fallback Completion Persistence

Low-energy fallback completion is partial progress, not full task completion.

When fallback only is completed, persist:

- `fallback_completed_at`;
- actual minutes when available;
- `needs_followup`;
- full task remains incomplete.

Later adjustment can account for remaining work without pretending the full task is done.

Fallback persistence belongs to active task progress, not draft review. V1 may add nullable fields to the active `tasks` table or a side table keyed by task id. Required logical fields are `fallback_completed_at`, `fallback_actual_minutes`, and `needs_followup`. Recording fallback completion must not set `completed_at` unless the full task was completed separately.

## Capacity Default

When no explicit learning capacity exists, initialize and use `daily_capacity_min = 60` and `reduced_capacity_min = 60`. The data layer must not reintroduce the older 300-minute fallback.
