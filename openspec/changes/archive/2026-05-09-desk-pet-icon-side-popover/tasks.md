## 1. MenuBarContentView（Popover）

- [x] 1.1 增加 `@AppStorage(MalDazeDefaults.idlePetIconSidePoints)`（或与既有存储对齐的绑定），在「桌宠动态强度」`VStack` **上方**新增「桌宠图标边长」Slider（步进 4，范围与 `MalDazeDefaults.idlePetIconSideMin…Max` 一致）；标签/两端文案简洁（可与强度滑杆风格对齐）。
- [x] 1.2 Slider 使用 **`onEditingChanged`**（或等效）：仅在拖动结束时写回持久化并 `post(name: MalDazeBroadcastNotifications.idlePetIconSidePointsChanged)`，避免拖动过程刷屏。
- [x] 1.3 按需上调 `MenuBarContentView.controlPanelPreferredContentSize.height`，确保新增一行不被裁切。

## 2. 设置页

- [x] 2.1 从 `MalDazeSettingsView`「桌宠回到右下角」Section **移除**桌宠图标边长 `Stepper` 及其 `onChange` 通知逻辑；保留同 Section 其他控件。
- [x] 2.2 若 `@AppStorage(MalDazeDefaults.idlePetIconSidePoints)` 仅在已删除 Stepper 处使用，清理未使用的存储绑定（避免编译告警）。

## 3. 测试与验证

- [x] 3.1 更新 `ControlPanelPresentationTests`（及任何硬编码「设置页发帖」断言）：改为断言 **`MenuBarContentView`** 在边长变更完成路径上投递 `idlePetIconSidePointsChanged`（或项目约定的等价覆盖方式）。
- [x] 3.2 运行相关测试靶：`MalDazeTests` 中与 Popover / 通知相关的子集。

## 4. 手动验证

- [x] 4.1 菜单栏与桌宠两处打开面板：边长滑杆在动态强度 **上方**；拖动结束窗口与点击区域随之变化；设置页不再出现边长 Stepper。

## 5. 与「桌宠动态强度」滑杆体验对齐（文档已定稿，实现跟进）

- [x] 5.1 **样式**：图标边长 Slider 去掉会产生刻度点的离散步进绑定（如 `step: 4`）；改为与强度滑杆一致的 **连续无极轨道**，拖动结束再将值 **量化到 4 pt 步进** 并写入 `@AppStorage` / 发帖。
- [x] 5.2 **手动**：并排对比两条滑杆，确认外观与拖动手感一致，无刻度点差异；松手后窗口边长仍为合法步进值。
