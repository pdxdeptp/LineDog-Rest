## Context

- `EnergyWakeupSourceTests` validates WindowManager cursor policy, break-run Hz, rest tick policy.
- No guardrails yet for FocusTimeline live gating or Dashboard quiescence.

## Goals / Non-Goals

**Goals:**

- Fail CI/dev check when regressions reintroduce known bad patterns.
- Document invariants for contributors.

**Non-Goals:**

- Instruments in CI.
- Profiling signposts (optional later).

## Decisions

### D1: Source inspection tests only

Continue `reduce-idle-energy` approach—parse Swift sources for forbidden patterns.

### D2: Invariant list (minimum)

1. `FocusTimelinePresenter`: no `setVisible(true)` → unconditional `startLiveTick`
2. `hideDashboardWindow`: calls quiescence pause / `enterHidden`
3. `ManualTimerEngine`: no `0.25, repeats: true` (post Change 3)
4. `InterventionRequestController`: no `3.0, repeats: true` poll (post Change 4)

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| Brittle string tests | assert on helper/policy names not line noise |
| False green | pair with M1 manual QA evidence |

## Migration Plan

1. Add spec + doc.
2. Extend tests as Changes 1–4 land.
3. `swift MalDazeTests/EnergyWakeupSourceTests.swift` in agent workflow optional step.

## Open Questions

- Add to Xcode test target vs standalone `@main` only—保持现有 standalone 可跑即可。
