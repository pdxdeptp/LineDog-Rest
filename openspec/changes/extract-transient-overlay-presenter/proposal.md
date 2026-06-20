## Why

MalDaze 的喝水提醒、中心铃铛和智能提醒浮层各自维护一套 AppKit 窗口代码（定位、`orderFrontRegardless`、屏幕监听、层级策略）。`orderFrontRegardless()` 会把整个应用的窗口栈抬高，导致已打开但被其他 App 挡住的 Dashboard 被意外拉到最前；`prevent-reminder-dismiss-surfacing-dashboard` 仅用 non-activating panel 缓解点击路径，未在展示层统一 z-order 契约。`docs/refactoring/refactor-todo.md` R22 已标记应提取共享展示逻辑，现在是用同一套原则一次性收敛三类浮层的合适时机。

## What Changes

- 引入 `MalDazeTransientOverlayPresenter`（R22）：统一临时浮层的创建、定位、展示、关闭与屏幕变化重定位。
- 将中心铃铛（`SevenMinuteReminderController` 铃铛路径、睡眠/干预委托）、喝水提醒、智能提醒输入/Toast 迁入该展示器；各控制器退化为调度/编排，不再直接持有 `NSPanel` 生命周期。
- 为**被动型**浮层（中心铃铛、喝水）内化 z-order 不变量：展示时不改变 Dashboard 相对其他 App 的层级；复用 `WindowManager` 已有的 `dashboard.order(.below, relativeTo: 0)` 策略，在弹出前 App 未激活时执行。
- 为**交互型**浮层（智能提醒输入）保留用户显式唤起语义：可 `activate` 并成为 key window，但不改变现有草稿、Esc/外部取消、锚点 clamp 行为。
- 保留现有用户可见文案、按钮、调度间隔、Hermes 契约与 Dashboard 显式打开入口（Dock、桌宠、快捷键）不变。
- 删除或瘦身重复的窗口样板代码（`HydrationReminderController` / `SevenMinuteReminderController` 内联 panel 逻辑；`SmartReminderUIPanels` 生命周期职责迁入展示器）。
- 更新聚焦测试与 OpenSpec 规格，覆盖展示器契约与各迁移入口。

## Capabilities

### New Capabilities

- `transient-overlay-presenter`: 共享临时浮层展示器——类型分档（被动/交互）、定位、生命周期、Dashboard z-order 不变量、屏幕参数变化处理。

### Modified Capabilities

- `hydration-reminder`: 浮层展示改经 `transient-overlay-presenter`；弹出时不得抬高已可见 Dashboard 相对其他 App 的层级（补齐 `prevent-reminder-dismiss-surfacing-dashboard` 未完成的 show 路径）。
- `sleep-reminder`: 睡前铃铛链 MUST 经共享展示器呈现中心铃铛，不得维护独立浮层 UI（措辞与实现一致）。
- `desk-pet-controls`: 智能提醒输入/Toast 改经共享展示器呈现；用户可见入口、草稿、锚点 clamp、提交语义不变。
- `desk-intervention`: 中心铃铛干预路径改经共享展示器；契约消费与倒计时逻辑不变。

## Impact

- **新增**: `MalDaze/TransientOverlay/`（或等价模块）— `MalDazeTransientOverlayPresenter` 及内容构建器。
- **重构**: `MalDaze/HydrationReminder/HydrationReminderController.swift`, `MalDaze/SevenMinuteReminder/SevenMinuteReminderController.swift`, `MalDaze/SmartReminder/SmartReminderUIPanels.swift`, `MalDaze/WindowManager/WindowManager.swift`, `MalDaze/AppViewModel.swift`.
- **调用方**: `SleepReminderController`, `InterventionRequestController`（`bellPresenter` API 可能变为展示器门面，行为不变）。
- **测试**: `MalDazeTests/ControlPanelPresentationTests.swift` 及新增展示器聚焦测试。
- **文档**: `docs/refactoring/refactor-todo.md` R22 可标为进行中/完成；`prevent-reminder-dismiss-surfacing-dashboard` 能力由本 change 吸收归档。
- **无影响**: Hermes JSON 契约、Timer 调度规则、Dashboard 标准窗口显式 focus 路径、休息霸屏 demote（已存在，可复用政策实现）。
