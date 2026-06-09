## Why

桌宠 Dashboard 目前是贴近桌宠的浮动 `NSPanel`：点外部会关、Mission Control 存在感弱、Dock 再点只会前置桌宠小窗。用户希望 Dashboard 成为 MalDaze 内的**标准窗口**——与桌宠同属一个 App，可在 Mission Control / Cmd+` 中切换，Dock 图标也能打开，且记住上次位置；同时保留桌宠左键入口（策略 A：只开/聚焦，不重新锚定）。

## What Changes

- 将 `DeskPetDashboardPanel`（`NSPanel` / floating）升级为标准 `NSWindow`（managed、`collectionBehavior` 适配 Mission Control）。
- **双入口、同一窗口实例**：桌宠左键与 Dock 再点均打开/聚焦同一 Dashboard 窗口；**策略 A**——不因桌宠点击而重算锚点位置。
- **位置持久化**：Dashboard 窗口 frame（origin + size）写入 `UserDefaults`；Dock 打开与桌宠打开均恢复上次位置；拖动/缩放后保存。
- **关闭语义变更**：
  - 移除「点外部关闭」与「应用失活关闭」。
  - 保留：再次触发打开动作 toggle 隐藏、Esc（经 `DeskPetDashboardEscapeRouter` 先关 sheet）、显式关闭（关闭钮 / Cmd+W，若实现）。
  - 隐藏后仍保留 SwiftUI host 与本地草稿状态（与现有一致）。
- **休息霸屏**：进入全屏休息时**不再**调用 `closeDeskMenuImmediate()`；Dashboard 保持打开，z-order 落在 `screenSaver` 桌宠霸屏之下（与其它 App 被盖住相同），休息结束后自然再可见。
- `applicationShouldHandleReopen`：Dock 再点 → 激活 App 并打开/聚焦 Dashboard（非仅桌宠小窗）。
- 更新 `ControlPanelPresentationTests` 与相关源文件测试约束。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `desk-pet-controls`：Dashboard 呈现载体（Panel → Window）、双入口、frame 持久化、关闭语义、休息叠层行为、Dock 入口。

## Impact

- **代码**：`WindowManager.swift`（主改动）、`MalDazeAppDelegate.swift`、`MalDazeDefaults.swift`（新持久化键）、`ControlPanelPresentationTests.swift`；可能移除 `DeskPetDashboardPanelLayout` 的锚点定位路径或仅保留首次默认居中逻辑。
- **不变**：`DashboardRootView`、`DeskPetDashboardView`、`AppViewModel`、学习面板与 Hermes 契约；桌宠小窗与休息霸屏逻辑（除「不再关 Dashboard」外）。
- **非目标**：第二个 `.app` bundle、Cmd+Tab 出现两个 App 图标、桌宠点击时重新锚在桌宠旁。
- **并行变更**：工作区存在 `rollout-scroll-month-date-picker` 等未提交改动；`opsx:apply` 前需避免与 `WindowManager` / `DashboardRootView` 冲突，或待用户确认合并顺序。

## Affected Specs

- `desk-pet-controls`
