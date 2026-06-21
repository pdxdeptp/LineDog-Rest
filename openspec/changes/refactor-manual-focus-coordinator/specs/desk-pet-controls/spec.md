## MODIFIED Requirements

### Requirement: 计时控制
控制面板 SHALL 提供手动番茄和整点/半点模式控制。手动番茄 SHALL follow Forest-honest actions only: **开始专注**, **放弃当前番茄**, and natural work-to-rest completion. MalDaze SHALL NOT provide user pause or resume for manual focus. Chrono persistence SHALL restore **only actively running** timer sessions after crash/relaunch, not user-suspended sessions.

#### Scenario: 模式切换
- **WHEN** 用户切换模式
- **THEN** 系统停止当前引擎
- **AND** 关闭休息窗口
- **AND** 若离开手动工作相，coordinator 将当前未完成工作相记为 `stoppedEarly`
- **AND** 清除任何可恢复的用户暂停 chrono 状态
- **AND** 按新模式更新状态行和宠物状态

#### Scenario: 手动专注开始
- **WHEN** 用户在手动模式且计时未运行点击“开始专注”
- **THEN** 系统启动 manual timer 进入新的工作相
- **AND** 设置计时会话 active

#### Scenario: 放弃当前番茄
- **WHEN** 用户在手动工作相点击“放弃当前番茄”
- **THEN** 系统停止 manual timer
- **AND** coordinator append `stoppedEarly` for the current work phase
- **AND** 清除 running chrono snapshot
- **AND** 不显示“恢复计时”入口

#### Scenario: 手动专注期间无停止计时
- **WHEN** 用户在手动模式且工作相正在运行
- **THEN** 控制面板不显示“停止计时”或“恢复计时”
- **AND** 显示“放弃当前番茄”作为唯一中断动作

#### Scenario: 自然完成进入休息
- **WHEN** manual 工作相自然结束
- **THEN** coordinator append `source: completed`
- **AND** 系统进入休息相并展示休息 UI

#### Scenario: 运行中 relaunch 恢复
- **WHEN** app 在 manual 计时运行中异常退出后重启且存在有效 running chrono snapshot
- **THEN** 系统恢复 manual 引擎相位
- **AND** replay 并写入错过的 completed focus sessions
- **AND** 不显示“恢复计时”（引擎自动继续）

#### Scenario: 无用户暂停 relaunch
- **WHEN** app 启动且仅存在 legacy 用户暂停 chrono 或 mode-only suspend token
- **THEN** 系统清除该状态
- **AND** 不启动计时引擎
- **AND** 不显示“恢复计时”

#### Scenario: 自动模式停止提醒
- **WHEN** 用户在整点/半点模式且自动引擎运行
- **THEN** 控制面板提供“停止自动提醒”而非“停止计时”
- **AND** 停止后不提供“恢复计时”
- **AND** 不写 focus session

## REMOVED Requirements

### Requirement: 停止计时 user suspend
**Reason**: Conflicts with Forest-honest manual focus; replaced by abandon-only interrupt.
**Migration**: Users who paused should abandon explicitly or rely on running relaunch after crash; legacy suspend snapshots cleared on load.

### Requirement: 恢复计时
**Reason**: Pause/resume removed; no third pomodoro state.
**Migration**: Start a new pomodoro with「开始专注」after abandon or natural completion.
