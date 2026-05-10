## Why

右下角桌宠使用 GIF 呈现线条小狗；部分用户希望在省电、减少干扰或截图场景下将图标改为静态（定格），而不影响其余控制面板功能。当前 `PetRenderer` 始终以动画方式播放 GIF，并提供定时轮换 GIF 素材，缺少用户可切换的「动态 / 静态」选项。

## What Changes

- **持久化开关**：在 `MalDazeDefaults` 增加布尔键（默认开启动画），记录用户是否允许桌宠 GIF 动态播放。
- **`PetRenderer` 行为**：根据开关设置 `NSImageView.animates`；关闭动态时停止 GIF 帧动画，并暂停「定期随机换一张 GIF」的定时器，避免静态模式下仍周期性跳图。
- **运行时同步**：新增广播通知（与 `idlePetIconSidePointsChanged` 同类）；`AppViewModel` 订阅后驱动 `WindowManager` / `PetStageView` 将最新偏好应用到 `PetRenderer`。
- **共享控制面板 UI**：在 **`MenuBarContentView`** 与现有番茄钟、提醒、快捷键等 Toggle **同一套布局区块内**增加「桌宠图标动态效果」开关（具体插入点与视觉层级与现有分组一致，**不得**单独做一条「顶栏」或与主面板割裂的壳层）。**菜单栏 `MenuBarExtra` 弹出的面板与桌宠 `NSPopover` 使用同一份 `MenuBarContentView`**，两处应对该开关 **同时可见、行为一致**（与「仅桌宠可见」相反）。
- **测试**：为 `PetRenderer`（及必要时集成点）补充单元测试；确认 `ControlPanelPresentationTests` 约束仍满足（不在 `MenuBarContentView` 内注入桌宠专用 presentation **环境变量**；普通 `@AppStorage` 控件与既有模式一致，允许保留）。

## Capabilities

### New Capabilities

- `desk-pet-icon-animation`: 用户在**共享控制面板**（菜单栏入口与桌宠入口均可打开）内切换桌宠图标是否动态显示；两处 UI **同步**；偏好持久化并立即作用于右下角桌宠窗口。

### Modified Capabilities

<!-- 仓库根目录 `openspec/specs/` 当前无已归档能力；无 delta spec。 -->

## Impact

- **修改**：`MalDaze/MalDazeDefaults.swift`、`MalDaze/PetRenderer/PetRenderer.swift`、`MalDaze/WindowManager/PetStageView.swift`、`MalDaze/WindowManager/WindowManager.swift`、`MalDaze/AppViewModel.swift`、`MalDaze/MalDazeBroadcastNotifications.swift`、**`MalDaze/MenuBarContentView.swift`**（新增 Toggle 区块；按需微调 `controlPanelPreferredContentSize` 高度以避免裁切）
- **新增测试**：`MalDazeTests/` 内针对本行为的用例
- **不影响**：菜单栏状态栏图标渲染路径（非 `PetRenderer`）；本开关仅影响右下角桌宠侧 `PetRenderer`
