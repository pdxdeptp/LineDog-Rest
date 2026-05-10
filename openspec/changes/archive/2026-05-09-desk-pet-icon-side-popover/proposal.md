## Why

常态桌宠图标边长已有可靠的存储（`UserDefaults`）、窗口与命中区同步链路；用户更希望在与动画强度相同的 **菜单栏 / 桌宠共用 Popover** 里就近调节大小，而不是打开完整设置里的 Stepper。将控件迁至面板可减少路径，并与「桌宠动态强度」滑杆形成一致的交互范式。

## What Changes

- 在 **`MenuBarContentView`** 中增加 **桌宠图标边长** 控件：连续拖动式调节（Slider），**纵向顺序上置于现有「桌宠动态强度」滑杆之上**，并保持菜单栏与桌宠两处 Popover 同一布局。
- **与「桌宠动态强度」滑杆的体验对齐**：图标边长滑杆在 **样式与拖动手感** 上应与强度滑杆一致——**连续无极轨道**（不因离散步进而出现轨道下方的刻度点）；合法 pt 仍按既有 **步进 4** 量化到存储（在拖动结束提交时取整），不改变 `UserDefaults` 或后端语义。
- **从 `MalDazeSettingsView` 的「桌宠回到右下角」分组中移除**该 Stepper 行（该分组内快捷键等与「归位」相关的项保留）。
- **不改动**边长的取值范围、默认值、`MalDazeDefaults` 键名，以及 `idlePetIconSidePointsChanged` → `AppViewModel` / `WindowManager` 的既有同步行为（仅在面板侧按与动画滑杆类似策略投递通知，避免拖动过程中刷屏）。

## Capabilities

### New Capabilities

- `desk-pet-icon-side-panel`: 定义常态桌宠图标边长在共用控制面板中的展示位置、与菜单栏/桌宠入口的一致性、与「桌宠动态强度」滑杆在 **连续轨道 / 无刻度** 体验上的一致性，以及从设置页移除重复入口后的可发现性约束（帮助文案或等价提示）。

### Modified Capabilities

- （无）当前仓库根目录 `openspec/specs/` 下尚无已合并的主规格；本变更以 delta 形式落在本 change 的 `specs/` 下。

## Impact

- **SwiftUI**：`MenuBarContentView.swift`（新增 `@AppStorage`、与强度滑杆一致的连续 Slider 外观、`onEditingChanged` 与通知）；`MalDazeSettingsView.swift`（删除 Stepper 块）。
- **测试**：`ControlPanelPresentationTests` / 其它扫描设置源码断言通知投递的测试需改为指向 **`MenuBarContentView`**（或同时覆盖两处若仍保留间接路径）。
- **布局**：`controlPanelPreferredContentSize` 可能需增加高度以容纳新的一行控件。
- **运行时**：沿用 `MalDazeBroadcastNotifications.idlePetIconSidePointsChanged` 与 `applyIdlePetIconSideFromUserDefaults()`，无新偏好键。
