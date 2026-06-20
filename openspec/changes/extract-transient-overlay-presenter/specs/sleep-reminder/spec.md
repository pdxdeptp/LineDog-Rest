## MODIFIED Requirements

### Requirement: 睡前铃铛链

系统 SHALL 通过 `SevenMinuteReminderController.presentCenterBellReminder(message:)` 门面调用 `MalDazeTransientOverlayPresenter` 展示睡眠铃铛，且 MUST NOT 为新睡眠提醒编写独立浮层 UI 或在睡眠控制器内维护 AppKit 浮层生命周期。

#### Scenario: 训练日洗澡提醒

- **WHEN** 距 `targetBedtime` 90 分钟到达
- **AND** 提醒链子开关开启
- **AND** 洗澡提醒开关开启
- **AND** 契约 `dayType` 为 `training`
- **THEN** 系统经共享展示器弹出铃铛，文案含洗澡提示

#### Scenario: 休息日跳过洗澡

- **WHEN** 距 `targetBedtime` 90 分钟到达
- **AND** 契约 `dayType` 为 `rest`
- **THEN** 系统 MUST NOT 弹出洗澡提醒

#### Scenario: 收尾与洗漱

- **WHEN** 距 `targetBedtime` 60 分钟或 30 分钟到达
- **AND** 提醒链子开关开启
- **THEN** 系统经共享展示器弹出对应语气的铃铛文案

#### Scenario: 截止铃铛

- **WHEN** `targetBedtime` 到达
- **AND** 提醒链子开关开启
- **THEN** 系统经共享展示器弹出截止铃铛（如「要睡觉了」）
- **AND** 用户点击后铃铛消失

#### Scenario: 睡眠铃铛不抬高 Dashboard

- **WHEN** 睡眠铃铛经共享展示器显示
- **AND** Dashboard 已可见但 MalDaze 在展示前未激活
- **THEN** 铃铛浮层位于最前
- **AND** Dashboard 相对其他 App 的层级保持不变
