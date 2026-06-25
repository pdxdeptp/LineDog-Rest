## Context

- `startPollTimerIfNeeded`: 3.0s repeating → `processPendingIfNeeded()`.
- `InterventionRequestFileWatcher` uses shared `FileChangeWatcher` (FSEvents 0.5s latency).
- `desk-intervention` spec: watch on start, FSEvents, wake, foreground activation.

## Goals / Non-Goals

**Goals:**

- Zero repeating poll in production intervention path.
- Parity with sleep schedule reliability model.

**Non-Goals:**

- Hermes JSON schema.
- Dashboard quiescence (intervention is app-global; acceptable).

## Decisions

### D1: Remove repeating pollTimer entirely

Wake/becomeActive + FSEvents cover missed events; if gap found in QA, add **one-shot** delayed reconcile after wake only—not periodic.

**Alternative rejected:** 60s poll—still patch.

### D2: Optional DEBUG-only poll

If field issues arise, `#if DEBUG` diagnostic poll behind flag—not shipped default.

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| FSEvents miss edge case | wake/becomeActive reconcile; manual QA Hermes write |
| External write while app suspended | wake reconcile on resume |

## Migration Plan

1. Remove poll timer start/stop.
2. Verify lifecycle observers call `processPendingIfNeeded`.
3. Tests + QA intervention bell.

## Open Questions

- None.
