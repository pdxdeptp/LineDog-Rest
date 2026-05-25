## Why

Validated task candidates are not useful until the system can honestly place them against deadline, daily capacity, existing load, rest days, unavailable dates, and buffer. The scheduler must be deterministic and must expose infeasibility instead of letting an LLM invent a cheerful calendar.

This change is the fourth split from `redesign-study-intake-planning`. It owns date placement, buffer reservation, low-capacity task splitting, risk reporting, infeasibility option generation, and deterministic option effects. It does not generate tasks or build the Add / Initiate UI.

## What Changes

- Add deterministic date placement for validated task candidates.
- Compute usable capacity from daily capacity, existing active load, rest days, and unavailable dates.
- Reserve buffer days when possible and report buffer erosion.
- Support balanced, front-loaded, and light-start load shapes.
- Split over-budget tasks into continuation sessions only at approved split points or explicit multi-session boundaries.
- Report capacity gap, overload, expected-late tasks, buffer erosion, rough estimate confidence, and existing-load conflicts.
- Generate canonical infeasibility options and deterministic option effects.
- Enforce hard-deadline guardrails, especially no `accept_late_finish` for hard deadlines.
- Add end-to-end capacity-math dry-run fixtures.

## Capabilities

### Affected Specs

- `study-intake-planning`

### New Capability

- `study-intake-planning`: deterministic deadline scheduling and infeasibility handling for Add / Initiate plan drafts.

## Impact

- Future backend/API: scheduler module, risk report, continuation sessions, infeasibility options, option-effect recomputation.
- Future UI can display risk and choices from this change, but rendering and interaction controls are not in scope.
