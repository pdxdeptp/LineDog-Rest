# MalDaze 实施任务

> 仓库：`MalDaze`（本 repo）。设计见 [design-maldaze.md](./design-maldaze.md)。Spec：`sleep-reminder`、`sleep-schedule-contract`（消费侧）、`break-interruption`、`desk-pet-controls`。

## 1. 契约读取

- [x] 1.1 新增 `SleepScheduleContract` 模型与 `SleepScheduleContractReader`（路径 `~/.hermes/data/sleep/sleep_schedule.json`，校验必填字段与 `dayType` 枚举）
- [x] 1.2 单元测试：完整契约、缺字段、非法 `dayType`、文件不存在

## 2. SleepReminderController

- [x] 2.1 新建 `MalDaze/SleepReminder/SleepReminderController.swift`（单次 Timer 链、注入 `SevenMinuteReminderController` + `WindowManaging`）
- [x] 2.2 实现 T-90/T-60/T-30/deadline 铃铛调度（文案按 spec）
- [x] 2.3 实现 `lockBedtime` fullscreen `presentRest`（`sleepLockActive` 标记，独立 `onDismissed`）
- [x] 2.4 实现 `didWake` 与可选 FSEvents 重载（`updatedAt` 变化重调度）
- [x] 2.5 单元测试：anchor 构建（跨午夜）、训练日/休息日 T-90 跳过

## 3. 合盖取消

- [x] 3.1 监听 `NSWorkspace.willSleepNotification`，仅当 `sleepLockActive` 时 `dismissRestImmediately`
- [x] 3.2 合盖时关闭睡眠链触发的铃铛浮层（不误伤独立 7 分钟倒计时）
- [x] 3.3 测试或文档化合盖路径（`SleepReminderClamshellTests` + Mock `WindowManager`）

## 4. AppViewModel 集成

- [x] 4.1 `MalDazeDefaults` 增加睡眠开关键
- [x] 4.2 `AppViewModel` 持有并启停 `SleepReminderController`；暴露 `sleepScheduleError`
- [x] 4.3 睡眠霸屏与计时器休息冲突时睡眠优先（spec `break-interruption`）

## 5. UI

- [x] 5.1 `DashboardRootView` 控制面板增加睡眠开关区
- [x] 5.2 契约无效时显示错误状态
- [x] 5.3 `MalDazeSettingsView` 镜像睡眠开关（与 hydration 一致）

## 6. 验证

- [x] 6.1 fixture JSON：`Fixtures/sleep_schedule_fixture.json` + `testDeadlineBellPrecedesLockByFiveMinutes`
- [x] 6.2 与 Hermes 联调：`integration_smoke` sleep_* 检查
