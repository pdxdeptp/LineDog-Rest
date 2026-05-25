## Why

Before the Plan Compiler or UI can safely generate and activate Add / Initiate plans, the system needs durable draft state that is separate from active Today/Calendar tasks. Without this split, a generated plan draft could leak into active workload before the user confirms it, and edits could activate stale assumptions.

This change is the second split from `redesign-study-intake-planning`. It owns draft persistence, draft/active separation, versioning, activation event recording, planning assumption storage, and fallback progress persistence. It does not generate phases/tasks or assign dates.

## What Changes

- Add plan draft persistence separate from active plans/tasks.
- Persist planning anchors and assumptions: deadline, capacity, target output, target depth, buffer policy, rest days, source roles, and provenance.
- Add draft schema version and draft version semantics.
- Reject stale draft activation safely.
- Record activation events linking intake item, assumptions, draft schedule version, and created active tasks.
- Persist fallback completion separately from full task completion.
- Normalize data-layer learning capacity default to 60 minutes when no user value exists.

## Capabilities

### Affected Specs

- `learning-data-layer`
- `study-intake-planning`

### Modified Capabilities

- `learning-data-layer`: persists draft plans, assumptions, activation events, draft/active separation, fallback progress, and consistent capacity default.

### New Capability

- `study-intake-planning`: lifecycle and version contracts for draft packages, activation, cancellation, and recompile boundaries.

## Impact

- Future backend/data: draft tables or equivalent storage, activation event records, version checks, fallback completion fields.
- Future compiler/scheduler/UI changes can rely on durable draft versions and Today exclusion.
- Existing active plan behavior remains downstream of explicit activation.
