## ADDED Requirements

### Requirement: 低唤醒自动休息调度
自动休息调度 SHALL avoid sub-second polling while waiting for the next `:00` or `:30` anchor.

#### Scenario: 等待下一锚点
- **WHEN** `AutoTimerEngine` starts and the next half-hour anchor is in the future
- **THEN** 系统 SHALL schedule a one-shot timer for that anchor
- **AND** 系统 MUST NOT run a repeating 4 Hz polling timer during the waiting phase

#### Scenario: 锚点到达
- **WHEN** the scheduled anchor is reached
- **THEN** `AutoTimerEngine` SHALL enter the scheduled rest phase
- **AND** it SHALL emit `.resting` state for the configured rest duration

#### Scenario: 休息倒计时
- **WHEN** `AutoTimerEngine` is in scheduled rest
- **THEN** it SHALL emit countdown updates only when the displayed whole-second remaining value changes

### Requirement: 全屏休息低频刷新
全屏休息 SHALL avoid continuous animation timer wakeups after the approach animation has completed.

#### Scenario: 接近动画期间
- **WHEN** 全屏休息的小狗正在从常态位置移动到屏幕中央
- **THEN** 系统 SHALL update the rest visual animation at an interactive cadence

#### Scenario: 接近动画完成后
- **WHEN** 全屏休息的小狗已到达中央且背景变暗动画完成
- **THEN** 系统 MUST NOT continue a high-frequency visual animation timer solely to refresh unchanged visuals
- **AND** 倒计时 SHALL continue updating at whole-second granularity

## MODIFIED Requirements

### Requirement: 跑屏休息
系统 SHALL 支持跑屏休息模式，让常态小窗在屏幕工作区内漫游，并 SHALL keep movement time-based so lower frame rates do not change perceived speed.

#### Scenario: 开始跑屏
- **WHEN** `presentBreakRun` 被调用
- **THEN** 系统保存出发前常态窗口 frame
- **AND** `PetStageView` 进入 breakRun display
- **AND** `BreakRunController` 开始移动窗口
- **AND** 显示屏幕左下角固定倒计时面板

#### Scenario: 跑屏移动
- **WHEN** 跑屏进行中
- **THEN** 系统以约 30 Hz 更新窗口位置
- **AND** 窗口在当前屏幕 visibleFrame 内边界反弹
- **AND** 按随机间隔和概率改变移动方向
- **AND** movement distance SHALL be based on elapsed time rather than assuming a fixed timer tick

#### Scenario: 跑屏时间到
- **WHEN** 跑屏休息时间到
- **THEN** 系统停止移动
- **AND** 隐藏遮罩和倒计时面板
- **AND** 桌宠用 1 秒动画返回休息前位置
- **AND** 调用休息结束回调
