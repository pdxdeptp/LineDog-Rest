## Why

macOS `cpu_resource.diag`（2026-06-16 / 21 / 22）显示 MalDaze 在 **Dashboard 关闭、用户 idle、autoWatching** 时仍可持续 ~50% CPU。栈采样指向 `FocusTimelinePresenter.liveTick` → `displayModel` `@Published` → SwiftUI AttributeGraph → Dashboard 大面积 layout（含 Today Todo 重测）。

`refactor-focus-timeline-presenter` 已在 spec 中要求：**仅 consumer visible 且 manual work active 时** 才 periodic live overlay refresh（design D3）。当前实现却在 `setVisible(true)` 时无条件启动 4 Hz timer，并在非 manual work 路径上 **每秒** 调用 `publishDisplayModel(overlay: nil)`，导致 `@Published` 持续 churn——属于 **D3 未完成**，不是新的产品需求。

本 change **补完** live gating 语义与 Presenter 状态机；Dashboard `orderOut` 生命周期由后续 change `add-dashboard-presentation-quiescence` 负责。

## What Changes

- 引入 `FocusTimelinePresenter` 显式状态机：`hidden` | `idle` | `live`。
- **删除** `setVisible(true)` 无条件 `startLiveTickIfNeeded()`。
- **删除** 非 manual work active 时的 periodic `publishDisplayModel(overlay: nil)`。
- Live 路径：4 Hz repeating → **1 Hz one-shot chain**（仅 `live` 态）。
- 新增 `refreshLiveScheduling()` 作为 timer 启停 **唯一入口**；manual phase / mode 事件驱动状态迁移。
- 收窄 `AppViewModel.refreshFocusSessionProjection`：skeleton 重建与 live overlay 分离；`handleTimeState` 仍不驱动 timeline。
- 扩展单测：visible × manualWork × hidden 状态矩阵。
- **不** 修改 Dashboard window lifecycle（Change 2）。
- **不** 用 Equatable 短路替代「不该 publish」语义（可选最后一道防线）。

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `focus-timeline-presenter`: 补全 D3 live gating——autoWatching visible 时无 periodic refresh；manual work + visible 时 ≤1 Hz overlay only；hidden 时 stop tick 并一次性清 overlay。

## Affected Specs

- `focus-timeline-presenter`（change delta；canonical 在 archive `refactor-focus-timeline-presenter` 后 promote，或本 change archive 时 merge）

## Depends On

- 现有实现与 spec 来自 `refactor-focus-timeline-presenter`（skeleton/live split 已完成；本 change 补 D3）。

## Blocks

- `add-dashboard-presentation-quiescence`（需 Presenter `enterHidden` / `setConsumerVisible` API）

## Impact

- **代码**:
  - `MalDaze/FocusSession/FocusTimelinePresenter.swift`
  - `MalDaze/AppViewModel.swift`
- **测试**:
  - `MalDazeTests/FocusTimelinePresenterTests.swift`
- **证据**:
  - `evidence/cpu-diag-baseline.md`
- **非目标**: WindowManager quiescence、ManualTimerEngine、Intervention poll、GIF baseline。
