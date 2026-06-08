## ADDED Requirements

### Requirement: 睡眠霸屏入口

系统 SHALL 支持由 `SleepReminderController` 在 `lockBedtime` 调用 `WindowManager.presentRest` 进入全屏霸屏，且该路径 MUST 使用 fullscreen 风格，不得路由到 `presentBreakRun`。

#### Scenario: 睡眠 lockBedtime

- **WHEN** `SleepReminderController` 在 `lockBedtime` 触发霸屏
- **THEN** 系统调用 `presentRest`
- **AND** 系统 MUST NOT 调用 `presentBreakRun`

### Requirement: 睡眠霸屏生命周期独立

睡眠链触发的霸屏 SHALL 使用独立结束回调，且 MUST NOT 在 `onDismissed` 中驱动 `ManualTimerEngine` 或 `AutoTimerEngine` 的休息跳过逻辑。

#### Scenario: 睡眠霸屏结束

- **WHEN** 睡眠霸屏通过合盖取消或时间结束而关闭
- **THEN** 计时器引擎状态 MUST NOT 因睡眠霸屏结束而被误修改
