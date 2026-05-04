## ADDED Requirements

### Requirement: Periodic hydration reminder scheduling
用户开启喝水提醒后，系统 SHALL 按照用户设定的间隔（分钟）周期性地弹出喝水提醒浮层。提醒仅在用户完成上一次操作（「已喝水」或「稍后提醒」）之后才重新调度，不得出现重叠的独立定时器。

#### Scenario: Timer fires after configured interval
- **WHEN** 用户开启喝水提醒且距上次操作已过 N 分钟（N 为用户设定间隔，默认 90）
- **THEN** 系统弹出喝水提醒浮层，浮层显示水滴图标、提示文案、「已喝水 💧」主按钮与「稍后提醒」次按钮

#### Scenario: No reminder when disabled
- **WHEN** 喝水提醒开关为关闭状态
- **THEN** 不弹出任何浮层，所有 Timer 均已停止

#### Scenario: Interval change takes effect on restart
- **WHEN** 用户在菜单栏面板修改间隔步进器的值后，关闭并重新开启喝水提醒
- **THEN** 新的 Timer 按修改后的间隔调度

### Requirement: Done action reschedules full interval
用户点击「已喝水 💧」后，系统 SHALL 关闭当前浮层并按完整间隔重新调度下一次提醒。

#### Scenario: Clicking done dismisses overlay and reschedules
- **WHEN** 喝水提醒浮层可见，用户点击「已喝水 💧」按钮
- **THEN** 浮层立即关闭，系统按完整间隔重新调度下一次提醒

#### Scenario: Done is idempotent when overlay not visible
- **WHEN** 浮层不可见（提醒尚未触发或已被关闭）
- **THEN** 系统不响应额外的 done 操作（不影响现有调度）

### Requirement: Snooze action reschedules 15 minutes
用户点击「稍后提醒」后，系统 SHALL 关闭当前浮层并在 15 分钟后重新触发提醒，忽略用户设定的完整间隔。

#### Scenario: Snooze dismisses overlay and reschedules 15 min
- **WHEN** 喝水提醒浮层可见，用户点击「稍后提醒」按钮
- **THEN** 浮层立即关闭，系统在 15 分钟后触发下一次提醒（不受用户设定间隔影响）

### Requirement: Enable/disable toggle in menu bar panel
用户 SHALL 能在菜单栏面板的「喝水提醒」区块通过 Toggle 控件开启或关闭喝水提醒；状态持久化到 UserDefaults。

#### Scenario: Toggle on starts scheduling
- **WHEN** 用户将 Toggle 从关闭拨到开启
- **THEN** 系统立即按当前间隔调度首次提醒，Toggle 保持开启状态

#### Scenario: Toggle off stops scheduling
- **WHEN** 用户将 Toggle 从开启拨到关闭
- **THEN** 系统取消现有 Timer，若当前有浮层则关闭，Toggle 保持关闭状态

#### Scenario: State persists across app restarts
- **WHEN** 用户保存开启状态后退出并重启 MalDaze
- **THEN** 喝水提醒依照上次保存的状态自动恢复（开启则重新调度，关闭则不调度）

### Requirement: Configurable interval via stepper
用户 SHALL 能通过步进器（Stepper）调整喝水提醒间隔，范围 15–240 分钟，步长 15 分钟，默认值 90 分钟；设置持久化到 UserDefaults。

#### Scenario: Stepper adjusts interval within bounds
- **WHEN** 用户在菜单栏面板增减步进器
- **THEN** 显示值更新为新间隔；新间隔在 15–240 分钟之间（超界时 Stepper 自动限制）

#### Scenario: Interval persists across app restarts
- **WHEN** 用户修改间隔后退出并重启 MalDaze
- **THEN** 步进器显示上次保存的间隔值

### Requirement: Overlay window appearance
喝水提醒浮层 SHALL 以屏幕中央圆角卡片形式出现，包含水滴图标、提示文案、两个操作按钮；风格与 SevenMinuteReminderController 铃铛浮层一致（相同 window level、圆角、半透明背景、阴影）。

#### Scenario: Overlay appears on primary display center
- **WHEN** 喝水提醒触发
- **THEN** 浮层居中显示在 `MenuBarNSScreen.screen`（菜单栏所在屏幕）的可见区域，window level 为 `.screenSaver`，可跨 Space 显示

#### Scenario: Overlay repositions on screen configuration change
- **WHEN** 浮层可见时用户插拔显示器或更改分辨率
- **THEN** 浮层自动移到新配置下菜单栏屏幕的中央
