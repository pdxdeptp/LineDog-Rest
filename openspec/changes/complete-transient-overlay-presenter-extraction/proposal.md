## Why

`extract-transient-overlay-presenter` 已完成被动浮层迁移，但审计发现智能提醒输入与 Toast 仍由 `WindowManager` 创建、持有和关闭，展示器也未处理交互型浮层的屏幕变化与关闭竞态。若直接归档，代码会违反该 change 已声明的生命周期 SSOT 与统一重定位契约，并保留可产生幽灵输入窗的真实回归风险。

## What Changes

- 完成智能提醒输入/Toast 的生命周期迁移：由 `MalDazeTransientOverlayPresenter` 创建、持有、定位、显示、关闭并释放交互型 panel；`WindowManager` 只保留草稿、提交、Esc/外部点击和自动关闭计时编排。
- 让展示器统一跟踪被动与交互型浮层，在屏幕参数变化后按各自策略重新居中或重新 clamp。
- 使交互型浮层关闭具备幂等与代际安全：已关闭或已被新实例替换的 panel 不得被延迟聚焦任务重新显示。
- 清理中心铃铛迁移后遗留的倒计时屏幕 observer 生命周期。
- 用行为测试覆盖交互型 ownership、屏幕变化、关闭后不复现，以及现有草稿/取消/Toast undo 语义；保留被动浮层 Dashboard z-order 聚焦验证。
- 在本 change 验证通过前，不归档 `extract-transient-overlay-presenter`；完成后按依赖顺序归档原 change 与本收尾 change。

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `transient-overlay-presenter`: 明确交互型浮层也必须由展示器独占 AppKit 生命周期，统一响应屏幕变化，并保证延迟聚焦不会复活已关闭或已替换的 panel。
- `desk-pet-controls`: 收紧智能提醒取消/替换后的可见性契约，确保草稿保留、提交、Toast undo 与自动关闭语义不变且不会出现幽灵窗口。

## Impact

- **核心代码**: `MalDaze/TransientOverlay/MalDazeTransientOverlayPresenter.swift`, `TransientOverlayDashboardPolicy.swift`, 智能提醒内容构建边界。
- **调用方瘦身**: `MalDaze/WindowManager/WindowManager.swift` 不再持有 `smartInputPanel` / `smartToastPanel` 或直接关闭 panel。
- **生命周期清理**: `MalDaze/SevenMinuteReminder/SevenMinuteReminderController.swift`。
- **测试**: `MalDazeTests/TransientOverlayPresenterTests.swift`, `ControlPanelPresentationTests.swift`，必要时新增可注入 panel/focus/screen doubles。
- **无影响**: Hermes JSON/命令契约、智能提醒草稿 SSOT、提醒文案和调度间隔、Dashboard 显式 focus 入口。
