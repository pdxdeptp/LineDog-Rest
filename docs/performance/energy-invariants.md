# Energy invariants (MalDaze)

Regression guardrails enforced by `MalDazeTests/EnergyWakeupSourceTests.swift` (run via Xcode test target or `swift MalDazeTests/EnergyWakeupSourceTests.swift` from repo root).

## Invariants

| Area | Invariant |
|------|-----------|
| Focus timeline | No unconditional 4 Hz live tick when `visible + autoWatching`; live tick only in manual-work `live` phase |
| Dashboard quiescence | `hideDashboardWindow` transitions presentation phase and pauses timeline (`enterHidden`) |
| Manual timer | No `0.25, repeats: true` in `ManualTimerEngine`; ≤1 Hz one-shot chain |
| Intervention | No `3.0, repeats: true` poll in `InterventionRequestController`; FSEvents + wake/becomeActive reconcile |
| Idle cursor | Adaptive far/near polling, not fixed 10 Hz |
| Break run | ~20 Hz movement with elapsed-time integration |
| Rest overlay | Whole-second cadence after approach completes |

## How to run

```bash
xcodebuild test -scheme MalDaze -destination 'platform=macOS' -only-testing:MalDazeTests/EnergyWakeupSourceTests
```

Or compile the standalone harness:

```bash
swift MalDazeTests/EnergyWakeupSourceTests.swift
```

## Manual QA (M1 release)

1. Enable auto-watching timer mode; open Dashboard → Today tab with focus timeline visible.
2. Close Dashboard; leave app idle in background **10 minutes**.
3. Expect: no sustained ~50% CPU; no repeating `liveTick → displayModel → AttributeGraph` stacks in Activity Monitor sample.

Evidence template: `openspec/changes/add-dashboard-presentation-quiescence/evidence/after-quiescence-idle-10min.md`.
