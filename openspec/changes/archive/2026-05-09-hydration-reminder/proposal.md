## Why

用户长时间盯屏工作时容易忘记喝水。PawPal 的喝水提醒功能已验证这一需求：按可配置间隔弹出浮层，用户点击「已喝水」或「稍后提醒」完成交互。将同等功能移植进 MalDaze，可在现有番茄钟体系之外提供一个独立的健康提醒层。

## What Changes

- **新增 `HydrationReminderController`**：独立控制器（仿 `SevenMinuteReminderController` 结构），持有周期性 `Timer`，到点弹出带按钮浮层（「已喝水」/「稍后提醒 15 分钟」）。
- **新增 `HydrationReminder/` 目录**：容纳控制器及浮层视图辅助类型。
- **修改 `MalDazeDefaults`**：新增 `hydrationReminderEnabled`、`hydrationReminderIntervalMinutes` 两个 UserDefaults 键。
- **修改 `AppViewModel`**：注入并持有 `HydrationReminderController`，暴露开关与间隔设置方法，发布 `isHydrationReminderEnabled` 状态供 UI 绑定。
- **修改 `MenuBarContentView`**：在独立倒计时 Divider 之后插入「喝水提醒」区块，含启停切换（Toggle）与间隔步进器（Stepper）。

## Capabilities

### New Capabilities

- `hydration-reminder`: 周期性喝水提醒——按用户设定间隔触发屏幕中央浮层，提供「已喝水」（重新计时）与「稍后提醒 15 分钟」（Snooze）两个操作；启停与间隔可在菜单栏面板内实时调整。

### Modified Capabilities

<!-- 无现有 spec 需要更新 -->

## Impact

- **新文件**：`MalDaze/HydrationReminder/HydrationReminderController.swift`
- **修改**：`MalDaze/MalDazeDefaults.swift`（2 个新键）
- **修改**：`MalDaze/AppViewModel.swift`（新增控制器持有、3 个公开方法、1 个 Published 属性）
- **修改**：`MalDaze/MenuBarContentView.swift`（新增 UI 区块）
- **修改**：`MalDaze.xcodeproj/project.pbxproj`（新增源文件引用）
- 无 API/IPC 变更；所有现有调用方不受影响。
