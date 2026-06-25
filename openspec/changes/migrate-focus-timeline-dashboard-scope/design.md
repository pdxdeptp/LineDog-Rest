## Context

- Presenter on AppViewModel since `refactor-focus-timeline-presenter` design D6 "倾向 AppViewModel 持有".
- Quiescence (Change 2) addresses ghost work without destroying presenter.
- Tension remains: two lifecycles (app vs dashboard host).

## Goals / Non-Goals

**Goals:**

- Evaluate whether host-scoped presenter reduces complexity vs quiescence-only.
- If go: clear ownership, no ghost state after host teardown.

**Non-Goals:**

- Required for M1 diag fix.
- Full Dashboard state destroy on hide.

## Decisions

### D1: Phase 0 spike only (default for this change)

Deliver design + decision record + optional prototype branch—not production migration in first apply unless metrics require.

### D2: If migrate—snapshot on hide

Preserve timeline day + skeleton via lightweight store on `AppViewModel` or file; presenter recreated on show.

**Alternative rejected:** destroy host on hide—breaks `dashboard-standard-window` state preservation.

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| Large regression surface | spike first; only proceed with evidence |
| Reopen latency | measure show Dashboard cold path |

## Migration Plan

1. Spike doc with pros/cons vs quiescence-only.
2. Decision: proceed or archive as "not needed".
3. If proceed: separate implementation change or expand tasks.

## Open Questions

- Proceed with migration? **Default: no until M2 metrics reviewed.**
