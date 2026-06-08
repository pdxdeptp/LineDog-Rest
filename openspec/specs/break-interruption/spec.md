# break-interruption Specification

## Purpose

MalDaze 在计时器进入休息阶段时展示桌宠打断体验。当前支持全屏霸屏休息和 PawPal 风格跑屏休息两种风格。
## Requirements
### Requirement: 休息入口路由
系统 SHALL 根据 `breakInterruptStyle` 选择休息展示方式。

#### Scenario: 全屏霸屏
- **WHEN** `breakInterruptStyle = fullscreen`
- **THEN** `AppViewModel` 调用 `WindowManager.presentRest`

#### Scenario: 跑屏
- **WHEN** `breakInterruptStyle = breakRun`
- **THEN** `AppViewModel` 调用 `WindowManager.presentBreakRun`

#### Scenario: 测试休息
- **WHEN** 用户点击“立即休息（测试）”
- **THEN** 系统按当前休息风格展示一次休息
- **AND** 使用当前配置的休息时长

### Requirement: 全屏休息
系统 SHALL 复用桌宠窗口进入全屏休息显示。

#### Scenario: 开始全屏休息
- **WHEN** `presentRest` 被调用
- **THEN** 系统关闭桌宠菜单
- **AND** 保存休息前常态窗口 frame
- **AND** 将窗口扩展到菜单栏屏幕全屏 frame
- **AND** 将窗口层级设为 `.screenSaver`
- **AND** `PetStageView` 开始 rest cycle

#### Scenario: 休息视觉
- **WHEN** 全屏休息开始
- **THEN** 小狗切换为 `.restingRed`
- **AND** 显示左下角倒计时
- **AND** 背景逐步变暗
- **AND** 小狗从休息前位置移动到屏幕中央并放大

#### Scenario: 休息结束
- **WHEN** rest cycle 时间到
- **THEN** 系统恢复窗口层级为 `.floating`
- **AND** 将窗口缩回常态桌宠 frame
- **AND** 调用休息结束回调

### Requirement: 全屏休息鼠标策略
系统 SHALL 根据用户设置决定全屏休息是否阻止点击桌面。

#### Scenario: 阻止点击开启
- **WHEN** restBlocksClicks 为 true 且红狗接近动画已完成
- **THEN** 全屏窗口接收鼠标事件，阻止背后桌面点击

#### Scenario: 阻止点击关闭
- **WHEN** restBlocksClicks 为 false
- **THEN** 鼠标在小狗命中区外时窗口穿透点击

#### Scenario: 接近动画期间
- **WHEN** 红狗还在移向中央
- **THEN** 小狗命中区外点击穿透到桌面

### Requirement: 全屏休息提前结束
系统 SHALL 支持连续点击桌宠提前结束全屏休息。

#### Scenario: 10 下结束
- **WHEN** 用户在休息期间连续点击中央小狗 10 下且每次间隔不超过 3 秒
- **AND** “单击 10 下桌宠可提前结束休息”设置开启
- **THEN** 系统立即关闭休息窗口
- **AND** 通知当前计时引擎跳过休息阶段

#### Scenario: 设置关闭
- **WHEN** “单击 10 下桌宠可提前结束休息”设置关闭
- **THEN** 连续点击不会提前结束休息

### Requirement: 跑屏休息
系统 SHALL 支持跑屏休息模式，让常态小窗在屏幕工作区内漫游。

#### Scenario: 开始跑屏
- **WHEN** `presentBreakRun` 被调用
- **THEN** 系统保存出发前常态窗口 frame
- **AND** `PetStageView` 进入 breakRun display
- **AND** 桌宠切换为 `.breakRunning`
- **AND** `BreakRunController` 开始移动窗口
- **AND** 显示屏幕左下角固定倒计时面板

#### Scenario: 跑屏移动
- **WHEN** 跑屏进行中
- **THEN** 系统以约 60 Hz 更新窗口位置
- **AND** 窗口在当前屏幕 visibleFrame 内边界反弹
- **AND** 按随机间隔和概率改变移动方向

#### Scenario: 跑屏时间到
- **WHEN** 跑屏休息时间到
- **THEN** 系统停止移动
- **AND** 隐藏遮罩和倒计时面板
- **AND** 桌宠用 1 秒动画返回休息前位置
- **AND** 调用休息结束回调

### Requirement: 跑屏遮罩与倒计时
系统 SHALL 在跑屏期间提供倒计时，并在长跑屏后显示轻遮罩。

#### Scenario: 固定倒计时面板
- **WHEN** 跑屏开始
- **THEN** 系统在菜单栏屏幕可见区左下角显示倒计时面板
- **AND** 面板层级高于跑屏遮罩、低于桌宠窗口

#### Scenario: 一分钟后遮罩
- **WHEN** 跑屏时长超过 60 秒
- **THEN** 系统在 60 秒后显示半透明遮罩
- **AND** 遮罩显示在跑屏小狗当前所在的物理显示器上
- **AND** 桌宠窗口升至 `.screenSaver` 层级，保持可点击

#### Scenario: 遮罩不跟随焦点屏
- **WHEN** 跑屏小狗在显示器 A 上运行
- **AND** 当前鼠标位置、键盘焦点或 `NSScreen.main` 指向显示器 B
- **THEN** 60 秒后的半透明遮罩显示在显示器 A 上

#### Scenario: 倒计时更新
- **WHEN** 跑屏进行中
- **THEN** 系统每秒更新小狗内倒计时和固定倒计时面板

### Requirement: 跑屏提前结束
系统 SHALL 支持通过点击跑屏小狗或倒计时面板提前结束。

#### Scenario: 点击小狗
- **WHEN** 用户在 3 秒内点击跑屏小狗 3 次
- **THEN** 系统触发提前结束休息

#### Scenario: 点击倒计时
- **WHEN** 用户连续点击固定倒计时面板 10 次
- **THEN** 系统触发提前结束休息

### Requirement: 计时器休息联动
系统 SHALL 在手动或自动计时器进入休息时展示休息打断。

#### Scenario: 手动休息
- **WHEN** ManualTimerEngine 进入 resting 状态
- **THEN** 若当前未展示休息，系统按当前休息风格展示休息

#### Scenario: 自动休息
- **WHEN** AutoTimerEngine 进入 scheduled rest 状态
- **THEN** 若当前未展示休息，系统按当前休息风格展示休息

#### Scenario: 暂停计时
- **WHEN** 用户停止计时
- **THEN** 系统关闭当前休息窗口或跑屏状态

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

