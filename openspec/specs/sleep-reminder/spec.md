# sleep-reminder Specification

## Purpose

MalDaze bedtime reminder chain (bells, lockBedtime fullscreen, clamshell dismiss) consuming Hermes `sleep_schedule.json`.
## Requirements
### Requirement: 启停与状态同步

系统 SHALL 通过 `AppViewModel` 持有 `SleepReminderController`，并将睡眠提醒总开关持久化到 UserDefaults。

#### Scenario: 开启睡眠提醒

- **WHEN** 用户打开睡眠提醒总开关
- **THEN** 系统读取 `sleep_schedule.json` 并启动提醒调度
- **AND** `isSleepScheduleEnabled` 变为 true

#### Scenario: 关闭睡眠提醒

- **WHEN** 用户关闭睡眠提醒总开关
- **THEN** 系统取消所有待触发睡眠 Timer
- **AND** 关闭睡眠链触发的铃铛与霸屏（若正在进行）

#### Scenario: 应用启动恢复

- **WHEN** 应用启动且睡眠总开关为 true
- **THEN** `AppViewModel` 尝试启动 `SleepReminderController`
- **AND** 若契约无效则报错且不调度

### Requirement: 契约消费与重调度

`SleepReminderController` SHALL 在启动、系统唤醒、以及检测到 `sleep_schedule.json` 的 `updatedAt` 变化时重读契约并重算当晚 Timer 链。

#### Scenario: updatedAt 变化

- **WHEN** `updatedAt` 与上次调度时不同
- **THEN** 系统取消旧 Timer 并按新 `targetBedtime` / `lockBedtime` 重调度

### Requirement: 睡前铃铛链

系统 SHALL 使用 `SevenMinuteReminderController.presentCenterBellReminder(message:)` 展示睡眠铃铛，且 MUST NOT 为新睡眠提醒编写独立浮层 UI。

#### Scenario: 训练日洗澡提醒

- **WHEN** 距 `targetBedtime` 90 分钟到达
- **AND** 提醒链子开关开启
- **AND** 洗澡提醒开关开启
- **AND** 契约 `dayType` 为 `training`
- **THEN** 系统弹出铃铛，文案含洗澡提示

#### Scenario: 休息日跳过洗澡

- **WHEN** 距 `targetBedtime` 90 分钟到达
- **AND** 契约 `dayType` 为 `rest`
- **THEN** 系统 MUST NOT 弹出洗澡提醒

#### Scenario: 收尾与洗漱

- **WHEN** 距 `targetBedtime` 60 分钟或 30 分钟到达
- **AND** 提醒链子开关开启
- **THEN** 系统弹出对应语气的铃铛文案

#### Scenario: 截止铃铛

- **WHEN** `targetBedtime` 到达
- **AND** 提醒链子开关开启
- **THEN** 系统弹出截止铃铛（如「要睡觉了」）
- **AND** 用户点击后铃铛消失

### Requirement: 躺平霸屏

系统 SHALL 在 `lockBedtime` 触发全屏霸屏，且 MUST 使用 `WindowManager.presentRest` 的 fullscreen 路径，不得使用 breakRun 风格。

#### Scenario: lockBedtime 霸屏

- **WHEN** `lockBedtime` 到达
- **AND** 霸屏子开关开启
- **THEN** 系统调用 `presentRest` 进入全屏霸屏
- **AND** 该霸屏 MUST NOT 驱动番茄计时引擎状态机

### Requirement: 合盖取消挡屏

当合盖取消子开关开启时，系统 SHALL 在 `NSWorkspace.willSleepNotification` 时取消睡眠链触发的霸屏，并关闭睡眠链触发的未关闭铃铛浮层。

#### Scenario: 合盖取消

- **WHEN** 系统即将睡眠且睡眠霸屏由睡眠链触发
- **AND** 合盖取消开关开启
- **THEN** 系统调用 `dismissRestImmediately`
- **AND** 关闭睡眠铃铛浮层（若仍显示）

### Requirement: 子开关

系统 SHALL 支持以下 UserDefaults 子开关，且仅在总开关开启时生效：

- 提醒链（T-90/60/30/deadline 铃铛）
- lockBedtime 霸屏
- 合盖取消挡屏
- T-90 洗澡提醒

#### Scenario: 关闭霸屏保留铃铛

- **WHEN** 用户关闭霸屏子开关但保持提醒链开启
- **THEN** 系统在 `lockBedtime` MUST NOT 调用 `presentRest`
- **AND** deadline 铃铛仍正常触发

### Requirement: 与计时器休息的优先级

当睡眠霸屏需要展示且护眼计时器正在休息展示时，睡眠霸屏 SHALL 优先于计时器休息展示。

#### Scenario: 冲突时睡眠优先

- **WHEN** `lockBedtime` 到达且计时器正处于休息霸屏或跑屏
- **THEN** 系统展示睡眠霸屏或先结束计时器休息展示再展示睡眠霸屏
- **AND** 睡眠霸屏结束 MUST NOT 误触发计时器 skip-rest 逻辑

