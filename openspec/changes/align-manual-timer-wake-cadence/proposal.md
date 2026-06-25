## Why

`ManualTimerEngine` 使用 **4 Hz** repeating timer，但 `tick()` 仅在整秒变化时 emit UI state——与 `AutoTimerEngine`（anchor one-shot + 1 Hz rest tick） philosophy 不一致。手动专注 + Dashboard 可见时，这与 `FocusTimelinePresenter` live tick 叠加，增加 MainActor wake，属于 **engine wake 频率与 UI 粒度不匹配** 的同类债务（`reduce-idle-energy` 已处理 auto engine，manual 未对齐）。

本 change 在 M1（Changes 1–2）消除 diag 峰值后，收敛 manual 路径 idle/active baseline。

## What Changes

- `ManualTimerEngine.scheduleTick`：4 Hz repeating → **1 Hz one-shot chain**（整秒 emit 行为不变）。
- 更新 `ManualTimerEnginePhaseReplayTests`。
- `EnergyWakeupSourceTests` 增加 manual engine 禁止 sub-second repeating 断言（完整 guardrails 集在 Change 6）。
- **不** 改变 work/rest 时长、phase 切换语义、status line 文案节奏。

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `break-interruption`: Manual timer engine SHALL NOT use sub-second repeating timers when UI consumers only require whole-second countdown updates.

## Depends On

- Recommended after `add-dashboard-presentation-quiescence`（M1 merged）；可与 Change 4 并行 apply。

## Impact

- `MalDaze/TimerEngine/ManualTimerEngine.swift`
- `MalDazeTests/ManualTimerEnginePhaseReplayTests.swift`
- `MalDazeTests/EnergyWakeupSourceTests.swift`（部分）
