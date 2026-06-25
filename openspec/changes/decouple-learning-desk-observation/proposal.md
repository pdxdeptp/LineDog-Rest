## Why

diag 栈显示 `FocusTimelinePresenter` publish 时 **Today Todo 文本重测** 也被卷入，说明 learning 列 invalidation 边界仍过粗。`refactor-focus-timeline-presenter` D4 要求时间轴 **不绑整个 AppViewModel** 的 tick；但 `LearningDeskPanelView` 仍 `@ObservedObject var appViewModel: AppViewModel`，Dashboard 整树观察面大，visible 时任何 VM publish 仍可能触发兄弟 subtree layout。

M1 消除 hidden ghost work 后，本 change 收窄 **visible 时** 的 observation 图，降低 collateral layout。

## What Changes

- 审计 `LearningDeskPanelView` / `DashboardRootView` 对 `AppViewModel` 的字段依赖。
- 引入窄接口（protocol / environment / command callbacks）供 learning panel actions。
- 时间轴 subtree **仅**观察 `FocusTimelinePresenter`（已部分完成，补全父级 invalidation）。
- 更新 `ControlPanelPresentationTests`。
- **不** 迁移 presenter 生命周期（Change 7）。

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `learning-desk-panel`: Learning desk SwiftUI subtree SHALL NOT invalidate on desk-pet status line or other AppViewModel fields unrelated to learning panel data.
- `focus-timeline-presenter`: Presenter publishes SHALL NOT require the learning panel root to observe the full AppViewModel.

## Depends On

- `add-dashboard-presentation-quiescence`（M1）

## Impact

- `MalDaze/LearningDeskPanel/LearningDeskPanelView.swift`
- `MalDaze/DashboardRootView.swift`（可能）
- `MalDaze/AppViewModel.swift`（窄 facade）
- `MalDazeTests/ControlPanelPresentationTests.swift`
