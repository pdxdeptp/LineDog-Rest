## Why

`dashboard-standard-window` 刻意 **隐藏后保留** `NSHostingController` 与 SwiftUI 状态（`orderOut`，非 destroy）。这与 SwiftUI `onDisappear` 语义 **不一致**：用户关 Dashboard 后，学习 Tab 上的 `FocusTimelinePresenter.setVisible(true)` 可能仍有效，4 Hz / 1 Hz timer 继续跑——这是 diag 里 **后台 idle ~50% CPU** 的直接触发条件之一。

在 `complete-focus-timeline-live-gating` 修正 Presenter 状态机之后，仍需要 **单一权威** 表达「Dashboard 是否允许 periodic work」。否则每个 panel 各自 `onDisappear` / 通知 / `setVisible(false)` 是 scattered patch，下一功能（nutrition watcher、EventKit 等）会复发。

## What Changes

- 引入 `DashboardPresentationPhase`（`.absent | .hidden | .visible`），由 `WindowManager` **唯一** 迁移。
- 引入 `DashboardQuiescenceCoordinator`：register / pause / resume periodic consumers。
- `hideDashboardWindow` → phase `.hidden` → **pause** 全部 registered consumers。
- `showDashboardWindow` → phase `.visible` → **resume** phase（watcher 仍由 panel `onAppear` lazy start）。
- 首批注册：`FocusTimelinePresenter`、`LearningDeskPanelViewModel`、`NutritionTodayViewModel`。
- 新增 `deskPetDashboardDidClose` 通知（与已有 `DidOpen` 对称）。
- SwiftUI `onAppear` / `onDisappear` **保留为 hint**，非 background work 唯一权威。
- **不** 修改 Presenter live gating 逻辑本身（Change 1）。
- **不** 销毁 host 或放弃 frame 持久化（与 `dashboard-standard-window` 一致）。

## Capabilities

### New Capabilities

- `dashboard-presentation-quiescence`: Dashboard window phase SSOT 与 periodic consumer pause/resume registry。

### Modified Capabilities

- `desk-pet-controls`: Dashboard hide SHALL quiesce registered periodic consumers；`onAppear`  alone SHALL NOT authorize background periodic work。
- `learning-desk-panel`: File watchers and live consumers SHALL pause when Dashboard phase is `.hidden`。

## Affected Specs

- `dashboard-presentation-quiescence` (new)
- `desk-pet-controls`
- `learning-desk-panel`

## Depends On

- `complete-focus-timeline-live-gating`（Presenter 需提供 `enterHidden()` / `setConsumerVisible(_:)`）

## Blocks

- Tier 2 changes benefit from quiescence model but can proceed after this change lands.

## Impact

- **代码**:
  - `MalDaze/WindowManager/WindowManager.swift`
  - `MalDaze/DashboardQuiescence/`（新模块，或 `AppViewModel` 内聚 coordinator）
  - `MalDaze/AppViewModel.swift`
  - `MalDaze/MalDazeBroadcastNotifications.swift`
  - Consumer hooks in `FocusTimelinePresenter`, `LearningDeskPanelViewModel`, `NutritionTodayViewModel`
- **测试**:
  - `MalDazeTests/DashboardQuiescenceTests.swift`（新）
  - `MalDazeTests/EnergyWakeupSourceTests.swift`（部分断言，完整集在 Change 6）
- **证据**:
  - `evidence/after-quiescence-idle-10min.md`
