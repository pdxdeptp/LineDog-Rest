## Why

The global repack planner from `fix-multi-project-learning-repack` fixed cross-project capacity overflow, but it still optimizes for early bin-packing rather than spreading lessons across each project's deadline window. Real schedules therefore pass `validate` while feeling wrong: lessons cluster in the first two weeks, multiple lessons land on the same day, and large deadline slack stays unused.

## What Changes

- Replace the greedy day-by-day fair queue with a three-phase pacing pipeline: **per-project spine → calendar merge → feasibility check**.
- Treat balanced cadence as a **hard pacing contract**: each project spreads ordered study tasks across its eligible deadline window per cumulative balanced targets.
- **Product rule (confirmed)**: when spine placement cannot satisfy cadence, shared capacity, order, and deadlines together, Hermes SHALL return `feasible: false` and require the user to **extend a deadline**, raise `daily_capacity_minutes`, or reduce scope. Hermes SHALL NOT auto-stack extra lessons on a day, front-load to finish early, or silently deviate from cadence.
- Surface structured `cadence_conflicts[]` / `capacity_conflicts[]` in CLI and MalDaze preview explaining which projects/dates block feasibility.
- Keep `fix-multi-project-learning-repack` contracts: global active reconciliation, transactional infeasibility on apply, aggregate validation, dry-run/apply parity, MalDaze as contract consumer only.
- **BREAKING**: repack/plan output dates will change for feasible snapshots; previously "valid but ugly" schedules may become explicitly infeasible until deadlines are extended.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `hermes-learning-calendar`: Spine-based spread-to-deadline; hard cadence; conflict → infeasible (no auto-compromise); additive diagnostics in CLI responses.
- `learning-desk-panel`: Show infeasibility and conflict facts from Hermes; block apply; guide user to extend deadline or adjust capacity.

## Impact

- **Hermes**: `schedule.py` planner core, learning-assistant tests, `set-deadline` / `plan` responses.
- **MalDaze**: deadline/repack preview models and copy only.
- **Data**: Users with tight multi-project windows may need to extend deadlines before repack succeeds.
- **Depends on**: `fix-multi-project-learning-repack` global capacity and preview fields.
