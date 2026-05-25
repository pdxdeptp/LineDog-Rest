## Why

The Add / Initiate redesign must start by stopping add-time inputs from becoming URL parser output or immediate todos. Before plan compilation exists, the system needs a reliable intake router that creates one pending intake item, proposes what role the item should play, and safely stores non-plan items.

This change is the first split from `redesign-study-intake-planning`. It owns intake item creation, source preview, role routing, confidence, one-question clarification, GitHub role handling, and non-plan storage. It does not generate plan drafts or schedule daily work.

## What Changes

- Add a bounded Add / Initiate intake router for text goals, URLs, GitHub repos, pasted notes, existing project items, interview prep items, and resume/project material.
- Route each item into a proposed role before any scheduled work is created:
  - `new_plan`
  - `attach_to_existing_plan`
  - `reference_material`
  - `later_resource`
  - `immediate_one_off`
- Model existing-plan support as `attach_to_existing_plan` plus `attachmentMode`, not as a competing machine role.
- Ask at most one routing question when the system cannot safely distinguish planning, attaching, storing, or one-off action.
- Treat material ingestion as a preview/helper during intake; preview must not write active resources, units, or tasks.
- Support shallow GitHub preview and canonical repo role signals without fabricating repo structure.
- Persist intake items and non-plan outcomes separately from active scheduled tasks.

## Capabilities

### Affected Specs

- `study-intake-planning`
- `material-ingestion`
- `learning-data-layer`

### New Capability

- `study-intake-planning`: intake routing and non-plan safety for Add / Initiate.

### Modified Capabilities

- `material-ingestion`: exposes intake preview and GitHub metadata without forcing schedulable resource creation.
- `learning-data-layer`: persists intake items and role-based relationships outside active tasks.

## Impact

- Future backend/API: route-intake endpoint, preview handoff, one-question clarification, non-plan storage.
- Future data: intake item rows, recommended/confirmed roles, calibration, attachment mode, and material/reference/later relationships.
- Existing URL ingestion remains available as a legacy compatibility path, but Add / Initiate does not call it in a way that creates active tasks before role confirmation.
