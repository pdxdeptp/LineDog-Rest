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

## Versioning

Every meaningful edit that changes anchors, scope, task estimates, task list, or schedule creates a new `draftVersion`.

Activation must verify:

- draft exists;
- draft status is activatable;
- requested draft version is the latest activatable version;
- activation has not already succeeded for that version.

If any check fails, no active tasks are created and the draft remains reviewable.

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

## Draft And Active Separation

Draft tasks are visible only through draft review surfaces. They must not appear in:

- Today;
- active Calendar facts;
- active deadline-risk alerts;
- smart-mode proposal triggers.

After activation, confirmed active tasks become eligible for existing Today, Calendar, adjustment, and smart-mode flows.

## Fallback Completion Persistence

Low-energy fallback completion is partial progress, not full task completion.

When fallback only is completed, persist:

- `fallback_completed_at`;
- actual minutes when available;
- `needs_followup`;
- full task remains incomplete.

Later adjustment can account for remaining work without pretending the full task is done.

## Capacity Default

When no explicit learning capacity exists, initialize and use `daily_capacity_min = 60` and `reduced_capacity_min = 60`. The data layer must not reintroduce the older 300-minute fallback.
