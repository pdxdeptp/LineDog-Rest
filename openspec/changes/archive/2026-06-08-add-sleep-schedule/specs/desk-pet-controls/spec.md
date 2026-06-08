## ADDED Requirements

### Requirement: 睡眠提醒控制面板开关

桌宠控制面板 SHALL 提供睡眠提醒总开关及子开关：提醒链、lockBedtime 霸屏、合盖取消挡屏、T-90 洗澡提醒。

#### Scenario: 总开关

- **WHEN** 用户在控制面板切换睡眠提醒总开关
- **THEN** 系统持久化 `MalDaze.sleepSchedule.enabled`
- **AND** 启停 `SleepReminderController`

#### Scenario: 子开关

- **WHEN** 用户切换任一睡眠子开关且总开关为开
- **THEN** 系统持久化对应 UserDefaults 键
- **AND** 重新调度当晚提醒链

### Requirement: 契约错误展示

当睡眠总开关为开且 `sleep_schedule.json` 无效时，控制面板 SHALL 向用户展示可读的错误状态（如「睡眠配置异常，请检查 Hermes 晨报」）。

#### Scenario: 缺 dayType

- **WHEN** 契约缺少 `dayType`
- **THEN** 控制面板显示错误状态
- **AND** 当晚不调度提醒
