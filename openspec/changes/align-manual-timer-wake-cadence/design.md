## Context

- `ManualTimerEngine` L160–167: `Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true)`.
- `tick()` uses `lastEmittedRemainingWholeSeconds` to emit at most once per whole second.
- `AutoTimerEngine` already uses one-shot anchors and ≤1 Hz rest ticks post `reduce-idle-energy`.

## Goals / Non-Goals

**Goals:**

- Manual engine MainActor wake ≤1 Hz while timer running.
- Preserve phase transitions, skip-rest, countdown display.

**Non-Goals:**

- AutoTimerEngine changes.
- Presenter / Dashboard quiescence.

## Decisions

### D1: 1 Hz one-shot chain

Mirror `AutoTimerEngine.scheduleRestTick`: fire at next whole second boundary; reschedule in tick handler.

**Alternative rejected:** Keep 4 Hz + skip emit——timer still wakes 4×/s.

### D2: Phase boundary immediate tick

On `start()`, `skipRestPhaseToWork()`, phase flip: schedule immediate sync tick then chain.

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| Sub-second phase end missed | one-shot at phaseEnd with small epsilon; replay tests |

## Migration Plan

1. Update replay tests for timing assumptions if any.
2. Implement one-shot chain.
3. Manual QA manual pomodoro full cycle.

## Open Questions

- None.
