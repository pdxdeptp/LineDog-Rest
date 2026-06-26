## Why

`add-dashboard-presentation-quiescence` 引入 Dashboard `orderOut` 静默化后，Hermes 文件 watcher（饮食 `daily_log.json` / `recommendation.json`、学习 `projects.json`）在 hide 时被可靠 `stopWatching()`，但 show 仍依赖 SwiftUI `onAppear` 恢复。Dashboard 使用 `orderOut` 保留 `NSHostingController` 时 **`onAppear` 不会在关→开后再触发**（同 change 设计文档 D1 已证 `onDisappear` 不可靠）。结果是：用户关过一次 Dashboard 后，饮食面板不再随 Hermes 更新自动刷新——与 quiescence 目标（停 CPU work、保留 UI state）矛盾，且违背该 change 原 proposal「register pause/resume consumers、AppKit phase 为 SSOT」的意图。

当前实现进一步偏离设计：coordinator 只有 `pauseAll`、无 `resumeAll`；饮食/学习 watcher 通过各 Panel 订阅 `deskPetDashboardDidClose` 零散 pause，而非 coordinator registry——属于 scattered patch，下一 consumer 仍会复发。

## What Changes

- 扩展 `DashboardQuiescenceCoordinator` 为 **对称** pause/resume registry；`transition(to: .visible)` 从 `.hidden` 进入时 **MUST** 调用 `resumeAll()`。
- 将 Dashboard 域 Hermes 观察者（`NutritionTodayViewModel`、`LearningDeskPanelViewModel`）**提升到 `AppViewModel` 持有**，在 init 向 coordinator 注册成对 pause/resume handler；**移除** Panel 内 `deskPetDashboardDidClose` / `onAppear` / `onDisappear` 对 watcher 生命周期的权威控制。
- Resume 时 file watcher consumers：`startWatching()` + 非阻塞 `loadToday()` / 等价 refresh（catch-up 隐藏期间错过的磁盘变更）；**不**恢复已删除的 45s 轮询。
- `FocusTimelinePresenter` 保持 tab-gated resume：`resume` 仅保证 `enterHidden` 对称解除 forced hidden；**不**在 show 时盲目 `setVisible(true)`（沿用 D3）。
- **MODIFIED** `dashboard-presentation-quiescence` spec：删除「show 不 eager restart file watchers、靠 onAppear」场景；改为 show 必须 resume 已注册 watcher consumers。
- **MODIFIED** `learning-desk-panel`、`nutrition-today-panel`（FSEvents 生命周期）requirements：hide stop / show resume 由 coordinator SSOT 驱动。
- 新增/扩展测试：hidden→visible 触发 resume；关→开 Dashboard 后 mock FSEvents 仍刷新饮食 panel。

## Capabilities

### New Capabilities

（无——本 change 完成既有 quiescence 能力，不引入新产品面。）

### Modified Capabilities

- `dashboard-presentation-quiescence`: show 时必须 resume 已注册 consumers；file watcher 不得依赖 `onAppear`。
- `learning-desk-panel`: Hermes projects file watcher 生命周期改由 quiescence coordinator SSOT。
- `nutrition-today-panel`: FSEvents 监听 hide stop / show resume 改由 quiescence coordinator SSOT；删除对 `onAppear` 作为恢复路径的隐含依赖。

## Impact

- **代码**:
  - `MalDaze/DashboardQuiescence/DashboardQuiescenceCoordinator.swift`
  - `MalDaze/AppViewModel.swift`（持有 nutrition/learning VMs，register consumers）
  - `MalDaze/DashboardRootView.swift`、`MalDaze/NutritionToday/NutritionTodayPanelView.swift`、`MalDaze/LearningDeskPanel/LearningDeskPanelView.swift`（ObservedObject + 移除 scattered pause）
  - `MalDaze/WindowManager/WindowManager.swift`（phase transition 已存在，无新 dismiss 语义）
- **测试**:
  - `MalDazeTests/DashboardQuiescenceCoordinatorTests.swift`
  - `MalDazeTests/NutritionTodayViewModelTests.swift`（resume catch-up）
  - 源码/集成测试：hide→show 后 watcher 非 nil
- **文档**: `docs/integrations/features/nutrition-today-panel.md`（FSEvents 生命周期一句对齐）
- **Depends on**: `add-dashboard-presentation-quiescence`（已 land 于 main `70531db`，本 change 为其 completion/fix）
