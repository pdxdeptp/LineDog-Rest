# desk-pet-controls Specification

## Purpose

桌宠和菜单栏共享同一个 `MenuBarContentView` 控制面板。用户可以从菜单栏或桌宠打开同一套控制项，并调整计时、休息、桌宠视觉和提醒相关设置。
## Requirements
### Requirement: 共享控制面板
系统 SHALL 在菜单栏和桌宠入口复用同一个 SwiftUI 控制面板。

#### Scenario: 菜单栏入口
- **WHEN** 用户打开菜单栏 Extra
- **THEN** 系统显示 `MenuBarContentView`

#### Scenario: 桌宠入口
- **WHEN** 用户左键点击常态桌宠命中区
- **THEN** 系统在桌宠旁显示 `NSPopover`
- **AND** popover 的 root view 为 `MenuBarContentView(viewModel:)`

#### Scenario: 全局快捷键入口
- **WHEN** 系统收到 `presentDeskPetMenu` 通知
- **THEN** `WindowManager` 以桌宠命中区为 anchor 打开桌宠菜单

### Requirement: Popover dismiss
系统 SHALL 使用自定义逻辑关闭桌宠菜单 popover。

#### Scenario: 再次点击桌宠
- **WHEN** 桌宠菜单已经打开且用户再次触发打开
- **THEN** 系统关闭该 popover

#### Scenario: 外部点击
- **WHEN** 用户点击 popover 窗口外部
- **THEN** 系统关闭该 popover

#### Scenario: Esc
- **WHEN** popover 打开且用户按 Esc
- **THEN** 系统关闭 popover
- **AND** 若智能输入面板正在显示，Esc 不由 popover 抢占

#### Scenario: 应用失活
- **WHEN** 应用失去 active 状态
- **THEN** 系统关闭 popover

### Requirement: 计时控制
控制面板 SHALL 提供手动番茄和整点/半点模式控制。系统 SHALL preserve a user-stopped timer session across app restarts until the user resumes, starts a new manual focus session, or switches timer mode.

#### Scenario: 模式切换
- **WHEN** 用户切换模式
- **THEN** 系统停止当前引擎
- **AND** 关闭休息窗口
- **AND** 清除已持久化的用户停止计时状态
- **AND** 按新模式更新状态行和宠物状态

#### Scenario: 手动专注
- **WHEN** 用户在手动模式点击“开始专注”
- **THEN** 系统启动 manual timer
- **AND** 设置计时会话 active
- **AND** 清除已持久化的用户停止计时状态

#### Scenario: 停止计时
- **WHEN** 用户点击“停止计时”
- **THEN** 系统停止当前计时引擎
- **AND** 显示“恢复计时”入口
- **AND** 持久化当前计时模式作为用户停止计时状态

#### Scenario: 启动时恢复停止计时状态
- **WHEN** app 启动且存在有效的用户停止计时状态
- **THEN** 系统恢复停止时的计时模式
- **AND** 不启动计时引擎
- **AND** 显示“恢复计时”入口
- **AND** 宠物显示暂停状态

#### Scenario: 恢复计时
- **WHEN** 用户点击“恢复计时”
- **THEN** 系统按当前模式重新启动对应计时引擎
- **AND** 清除已持久化的用户停止计时状态

#### Scenario: 忽略无效停止计时状态
- **WHEN** app 启动且持久化的用户停止计时状态不是有效计时模式
- **THEN** 系统清除该无效状态
- **AND** 使用无停止状态时的默认启动行为

### Requirement: 番茄时长设置
系统 SHALL 允许用户配置手动专注时长和休息时长。

#### Scenario: 专注时长
- **WHEN** 用户修改专注间隔
- **THEN** 系统将工作时长 clamp 到 5...120 分钟
- **AND** 同步到 `ManualTimerEngine`

#### Scenario: 休息时长
- **WHEN** 用户修改休息时长
- **THEN** 系统将休息时长 clamp 到 1...60 分钟
- **AND** 同步到手动和自动计时引擎

### Requirement: 休息行为设置
控制面板 SHALL 支持配置休息期间行为。

#### Scenario: 阻止点击桌面
- **WHEN** 用户切换“休息期间阻止点击桌面”
- **THEN** 系统持久化设置
- **AND** 调用 `WindowManager.setRestBlocksClicks`

#### Scenario: 20 下结束休息
- **WHEN** 用户切换“单击 20 下桌宠可提前结束休息”
- **THEN** 系统持久化该设置

#### Scenario: 休息风格
- **WHEN** 用户选择“霸屏（强）”或“跑屏（轻）”
- **THEN** 系统写入 `MalDaze.breakInterruptStyle`
- **AND** 后续休息按该风格展示

### Requirement: 桌宠视觉设置
控制面板 SHALL 提供桌宠图标边长和动态强度控制。

#### Scenario: 图标边长滑杆
- **WHEN** 用户拖动并提交图标边长滑杆
- **THEN** 系统量化并保存新边长
- **AND** 发送 `idlePetIconSidePointsChanged` 通知

#### Scenario: 动态强度滑杆
- **WHEN** 用户拖动并提交桌宠动态强度滑杆
- **THEN** 系统保存 0...1 强度
- **AND** 发送 `idlePetAnimationIntensityChanged` 通知

### Requirement: 智能提醒入口
桌宠 SHALL 支持从右键或全局快捷键打开智能提醒输入。

#### Scenario: 桌宠右键
- **WHEN** 用户右键点击桌宠命中区
- **THEN** 系统以该命中区为 anchor 打开智能提醒输入面板

#### Scenario: 全局智能提醒快捷键
- **WHEN** 系统收到 `openSmartReminderInput` 通知
- **THEN** 系统以桌宠窗口或默认底部 anchor 打开智能提醒输入面板

#### Scenario: 输入草稿保留
- **WHEN** 用户点外部、Esc 或取消关闭智能提醒输入
- **THEN** 系统保留草稿文本

#### Scenario: 提交成功清空
- **WHEN** 智能提醒成功写入且草稿仍等于本次提交文本
- **THEN** 系统清空草稿

### Requirement: 宽屏桌宠菜单 popover
桌宠控制面板 popover SHALL 使用接近当前屏幕可见宽度的横向布局，并将中间学习助手栏设为自适应主区域。

#### Scenario: 桌宠入口打开宽屏 popover
- **WHEN** 用户左键点击常态桌宠命中区打开桌宠菜单
- **THEN** 系统显示 `MenuBarContentView(viewModel:)`
- **AND** popover 横向宽度接近当前屏幕可见宽度并保留安全边距
- **AND** popover 不超过当前屏幕可见区域

#### Scenario: 左右栏固定宽度
- **WHEN** popover 计算三栏布局
- **THEN** 左侧提醒栏保持固定宽度
- **AND** 右侧控制栏保持固定宽度
- **AND** 分隔线和外边距保持固定宽度

#### Scenario: 学习助手栏自适应
- **WHEN** 当前屏幕可见宽度大于三栏最小宽度
- **THEN** 中间学习助手栏获得左右栏之外的剩余宽度
- **AND** 学习助手栏宽度随屏幕宽度增加而增加

#### Scenario: 窄屏降级
- **WHEN** 当前屏幕可见宽度不足以展示目标宽屏宽度
- **THEN** popover 宽度被 clamp 到当前屏幕可见区域内
- **AND** 学习助手栏保持最小可读宽度

#### Scenario: 关闭行为保持
- **WHEN** 宽屏 popover 打开后用户再次点击桌宠、点击外部、按 Esc 或应用失活
- **THEN** 系统保持现有 popover dismiss 行为

### Requirement: Dashboard right controls hierarchy
The Dashboard right controls column SHALL present existing desk-pet controls with a clear hierarchy that separates live status, common actions, configuration, utilities, and destructive actions.

#### Scenario: First screen shows status and common actions
- **WHEN** the Dashboard panel opens
- **THEN** the right controls column displays the current status line near the top
- **AND** the column displays the timer mode control near the top
- **AND** the column displays primary everyday actions before lower-frequency settings

#### Scenario: Settings remain available without dominating
- **WHEN** the user scans the right controls column
- **THEN** timer duration, rest behavior, pet appearance, hydration quiet hours, and break style controls remain reachable
- **AND** these lower-frequency controls do not visually compete with the primary everyday actions

#### Scenario: Utility and destructive actions are separated
- **WHEN** the right controls column renders reset, test, quit, or equivalent utility actions
- **THEN** those actions are visually separated from the primary timer, reminder, hydration, and companion actions
- **AND** the quit action is not grouped with everyday timer controls

#### Scenario: Accessible control targets
- **WHEN** the right controls column renders clickable or tappable controls
- **THEN** each primary control provides a clear label or accessibility label
- **AND** icon-only controls have an accessible name
- **AND** controls maintain comfortable spacing to avoid accidental activation

#### Scenario: Existing behavior preserved
- **WHEN** the right controls column is redesigned
- **THEN** existing capabilities for timer modes, manual focus, stop/resume, rest behavior, pet appearance, countdown reminder, hydration reminder, cat companion, settings, and quit remain available
- **AND** the redesign does not change persistence keys or timer/reminder business logic
- **AND** active accents, primary buttons, and non-rest status indicators use the app's pale-blue accent instead of green

### Requirement: Dashboard right controls interactions
The Dashboard right controls column SHALL map each visible action to an explicit state-aware interaction while preserving existing view-model behavior.

#### Scenario: Settings action
- **WHEN** the user activates the settings gear
- **THEN** the system opens the existing MalDaze settings window

#### Scenario: Mode action
- **WHEN** the user selects a timer mode
- **THEN** the system calls the existing mode-change behavior
- **AND** current timer, rest, status, and pet-state side effects remain unchanged

#### Scenario: Manual focus action
- **WHEN** the current mode is manual and no timer session is active or suspended
- **THEN** the primary timer action starts a manual focus session

#### Scenario: Stop timer action
- **WHEN** a timer session is active and stoppable
- **THEN** the primary timer action stops timers

#### Scenario: Resume timer action
- **WHEN** a timer session is suspended
- **THEN** the primary timer action resumes timers

#### Scenario: Non-manual idle timer action
- **WHEN** the current mode is not manual and no manual start action is valid
- **THEN** the primary timer action does not start a manual focus session
- **AND** the UI communicates that automatic timing is controlled by the selected mode

#### Scenario: Countdown action
- **WHEN** the countdown reminder is not running
- **THEN** the countdown action starts the reminder using the configured duration
- **AND** when the countdown reminder is running, the same action changes to a cancel action

#### Scenario: Hydration settings action
- **WHEN** hydration reminders are disabled
- **THEN** the hydration action inside hydration settings enables hydration reminders
- **AND** when hydration reminders are enabled, the same action disables hydration reminders

#### Scenario: Cat companion action
- **WHEN** the cat companion is inactive
- **THEN** the cat action starts the cat companion
- **AND** when the cat companion is active, the same action changes to an early close action

#### Scenario: Disclosure sections
- **WHEN** the user opens or closes a settings disclosure section
- **THEN** the system changes only the local presentation state
- **AND** no timer, reminder, hydration, pet, or quit behavior runs from disclosure header activation

#### Scenario: Footer utility actions
- **WHEN** the user activates reset pet, test rest, test hydration, or quit
- **THEN** each action calls its existing view-model behavior
- **AND** test and quit actions remain visually separated from everyday quick actions
