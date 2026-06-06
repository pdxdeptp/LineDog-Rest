# desk-pet-controls Specification

## Purpose

桌宠和菜单栏共享同一个 `MenuBarContentView` 控制面板。用户可以从菜单栏或桌宠打开同一套控制项，并调整计时、休息、桌宠视觉和提醒相关设置。
## Requirements
### Requirement: 共享控制面板
系统 SHALL 将桌宠控制面板保留为桌宠入口专属的富控制面板，并 SHALL 将菜单栏入口拆分为独立的设置菜单。桌宠入口和桌宠菜单快捷键 SHALL 继续打开 `MenuBarContentView(viewModel:)`，菜单栏入口 SHALL NOT 直接显示 `MenuBarContentView`。

#### Scenario: 菜单栏入口
- **WHEN** 用户打开菜单栏 Extra
- **THEN** 系统显示独立的小菜单
- **AND** 小菜单只包含一个设置按钮
- **AND** 系统不在菜单栏 Extra 内容中构造 `MenuBarContentView(viewModel:)`

#### Scenario: 菜单栏设置按钮
- **WHEN** 用户在菜单栏小菜单中点击设置按钮
- **THEN** 系统调出桌宠的设置界面
- **AND** 设置界面复用 `MalDazeSettingsView`

#### Scenario: 桌宠入口
- **WHEN** 用户左键点击常态桌宠命中区
- **THEN** 系统在桌宠旁显示 `NSPopover`
- **AND** popover 的 root view 为 `MenuBarContentView(viewModel:)`

#### Scenario: 全局快捷键入口
- **WHEN** 系统收到 `presentDeskPetMenu` 通知
- **THEN** `WindowManager` 以桌宠命中区为 anchor 打开桌宠菜单
- **AND** 桌宠菜单的 root view 为 `MenuBarContentView(viewModel:)`

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
桌宠 SHALL 支持从右键或全局快捷键打开智能提醒输入，并 SHALL 使用可承载长自然语言文本的紧凑多行输入面板。

#### Scenario: 桌宠右键
- **WHEN** 用户右键点击桌宠命中区
- **THEN** 系统以该命中区为 anchor 打开智能提醒输入面板
- **AND** 输入面板默认聚焦文本输入区

#### Scenario: 全局智能提醒快捷键
- **WHEN** 系统收到 `openSmartReminderInput` 通知
- **THEN** 系统以桌宠窗口或默认底部 anchor 打开智能提醒输入面板
- **AND** 输入面板默认聚焦文本输入区

#### Scenario: 长文本可见
- **WHEN** 用户输入超过单行宽度的自然语言计划文本
- **THEN** 输入文本在面板内换行显示
- **AND** 面板提供多行可读高度，而不是只显示单行横向截断内容

#### Scenario: 输入面板尺寸受控
- **WHEN** 用户继续输入很长的文本
- **THEN** 输入面板保持在预设最大高度内
- **AND** 文本输入区保持可继续编辑，不扩大成全屏或遮挡式窗口

#### Scenario: 输入面板保持在可见屏幕区域内
- **WHEN** 用户在靠近屏幕右下角或右侧 Dock 的桌宠上打开智能提醒输入
- **THEN** 系统将输入面板 frame clamp 到 anchor 所在屏幕的 `visibleFrame` 内
- **AND** 输入面板不超出屏幕右边界
- **AND** 输入面板不被右侧 Dock 覆盖

#### Scenario: 输入草稿保留
- **WHEN** 用户点外部、Esc 或取消关闭智能提醒输入
- **THEN** 系统保留草稿文本

#### Scenario: 提交成功清空
- **WHEN** 智能提醒成功写入且草稿仍等于本次提交文本
- **THEN** 系统清空草稿

#### Scenario: 显式提交
- **WHEN** 用户通过输入面板的提交动作添加提醒
- **THEN** 系统将完整草稿文本提交给智能提醒编排流程

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

### Requirement: Dashboard Panel presentation
桌宠 Dashboard Panel SHALL replace the desk pet `NSPopover` presentation with a dedicated panel-style dashboard surface.

#### Scenario: Panel creation
- **WHEN** 桌宠 Dashboard Panel 首次需要显示
- **THEN** 系统创建 `NSPanel` 或等价 `NSPanel` 子类
- **AND** panel 背景允许 SwiftUI root view 绘制自己的圆角、材质和阴影
- **AND** panel 不显示 popover 箭头

#### Scenario: Key window behavior
- **WHEN** Dashboard Panel 中存在文本输入、按钮或 SwiftUI 控件
- **THEN** panel 支持成为 key window 或提供等价焦点能力
- **AND** 用户可以正常输入文本并操作控件

#### Scenario: Repeat presentation
- **WHEN** Dashboard Panel 已经创建且用户再次从桌宠入口打开
- **THEN** 系统复用既有 panel 和 SwiftUI host
- **AND** 不因重复打开而重新冷创建整个 dashboard 视图树

### Requirement: Dashboard Panel dismissal
系统 SHALL 使用自定义逻辑关闭桌宠 Dashboard Panel。

#### Scenario: 再次点击桌宠
- **WHEN** Dashboard Panel 已经打开且用户再次触发桌宠打开动作
- **THEN** 系统关闭或隐藏该 Dashboard Panel

#### Scenario: 外部点击
- **WHEN** 用户点击 Dashboard Panel 窗口外部
- **THEN** 系统关闭或隐藏该 Dashboard Panel

#### Scenario: Esc
- **WHEN** Dashboard Panel 打开且用户按 Esc
- **THEN** 系统关闭或隐藏 Dashboard Panel
- **AND** 若子面板或输入流程正在处理 Esc，Dashboard Panel 不抢占该事件

#### Scenario: 应用失活
- **WHEN** 应用失去 active 状态
- **THEN** 系统关闭或隐藏 Dashboard Panel

#### Scenario: State preservation on hide
- **WHEN** 系统隐藏 Dashboard Panel
- **THEN** 系统保留 dashboard 本地 UI 状态和草稿状态
- **AND** 下一次打开可恢复仍然有效的本地状态

### Requirement: 宽屏桌宠 Dashboard Panel
桌宠 Dashboard Panel SHALL 使用接近当前屏幕可见宽度的横向布局，并将中间主内容区域设为自适应区域。

#### Scenario: 桌宠入口打开宽屏 Dashboard Panel
- **WHEN** 用户左键点击常态桌宠命中区打开 Dashboard Panel
- **THEN** 系统显示 dashboard root view
- **AND** panel 横向宽度接近当前屏幕可见宽度并保留安全边距
- **AND** panel 不超过当前屏幕可见区域

#### Scenario: 左右栏固定宽度
- **WHEN** Dashboard Panel 计算三栏布局
- **THEN** 左侧提醒栏保持固定宽度
- **AND** 右侧控制栏保持固定宽度
- **AND** 分隔线和外边距保持固定宽度

#### Scenario: 主内容区域自适应
- **WHEN** 当前屏幕可见宽度大于三栏最小宽度
- **THEN** 中间主内容区域获得左右栏之外的剩余宽度
- **AND** 主内容区域宽度随屏幕宽度增加而增加

#### Scenario: 窄屏降级
- **WHEN** 当前屏幕可见宽度不足以展示目标宽屏宽度
- **THEN** panel 宽度被 clamp 到当前屏幕可见区域内
- **AND** 中间主内容区域保持最小可读宽度

#### Scenario: Panel position
- **WHEN** Dashboard Panel 从桌宠入口打开
- **THEN** 系统优先将 panel 放置在桌宠附近
- **AND** 若桌宠位置会导致 panel 超出可见区域，系统将 panel 移入当前屏幕可见区域

### Requirement: Settings category boundaries
The MalDaze settings window SHALL keep credentials, shortcut recorders, and runtime startup controls in semantically correct settings surfaces without cross-category leakage or visual overlap.

#### Scenario: Model credentials page excludes unrelated controls
- **WHEN** the user opens the "模型与密钥" settings category
- **THEN** the detail pane SHALL show Smart Input LLM provider/model/API-key configuration
- **AND** the detail pane SHALL NOT show shortcut recorder controls such as "录制", "恢复默认", or Smart Input "添加提醒"

#### Scenario: Provider selection uses compact dropdown controls
- **WHEN** the user opens the "模型与密钥" settings category
- **THEN** the Smart Input LLM surface SHALL render the service-provider selector as a dropdown or popup menu control
- **AND** the provider selector SHALL visually align with the model dropdown control
- **AND** the provider selector SHALL NOT render as a segmented control

#### Scenario: Shortcut page contains every global shortcut recorder
- **WHEN** the user opens the "快捷键" settings category
- **THEN** the detail pane SHALL show all global shortcut recorder rows
- **AND** the Smart Input "添加提醒" shortcut row SHALL appear with the other shortcut rows
- **AND** each shortcut row SHALL keep its current record, restore-default, default-copy, and storage behavior

#### Scenario: Category helper copy matches selected category
- **WHEN** the user opens any settings category
- **THEN** persistent helper copy in the settings shell SHALL match the selected category's purpose
- **AND** API-key-specific helper copy SHALL NOT remain visible while the selected category is "快捷键"

#### Scenario: Category content does not visually bleed or overlap
- **WHEN** the user switches between settings categories, scrolls the detail pane, or uses the default settings window size
- **THEN** controls SHALL remain inside their owning category content
- **AND** controls SHALL NOT overlap card boundaries, section separators, or adjacent rows
- **AND** no row from another category SHALL be partially visible as if it belongs to the selected category

### Requirement: 计划侧栏三个月展示窗口
桌宠 Dashboard 的左侧「计划」侧栏 SHALL 从所选系统提醒事项列表中展示截止日期处于今天至三个月后本地日期内（含三个月后的当天）的未完成提醒，并 SHALL 继续包含今天之前已到期但未完成的提醒。

#### Scenario: 展示未来三个月提醒
- **WHEN** 用户打开桌宠 Dashboard 且已授权提醒事项访问
- **AND** 所选列表中存在截止日期处于今天至三个月后本地日期内（含三个月后的当天）的未完成提醒
- **THEN** 「计划」侧栏显示这些提醒
- **AND** 按本地日期分组并按截止时间排序

#### Scenario: 不展示三个月窗口外提醒
- **WHEN** 所选列表中存在截止日期晚于三个月后本地日期的未完成提醒
- **THEN** 「计划」侧栏不显示该提醒

#### Scenario: 保留逾期提醒
- **WHEN** 所选列表中存在今天之前已到期但未完成的提醒
- **THEN** 「计划」侧栏继续显示该逾期提醒

### Requirement: MalDaze settings window hierarchy
The system SHALL present the MalDaze settings window opened from the Dashboard settings gear or menu bar settings action as a structured settings surface rather than a single undifferentiated raw form.

#### Scenario: Settings window opens with categories
- **WHEN** the user activates the Dashboard right-column settings gear
- **THEN** the system opens the existing MalDaze settings window
- **AND** the window presents distinct settings categories for Smart Input and shortcuts
- **AND** the selected category's details are visually separated from the category navigation

#### Scenario: Existing settings remain reachable
- **WHEN** the redesigned settings window renders
- **THEN** controls remain available for Smart Input provider, Smart Input model, selected-provider API key, and all existing shortcut recorders
- **AND** the redesign does not change existing persistence keys, provider model IDs, or shortcut default values

#### Scenario: Window sizing supports the redesigned layout
- **WHEN** the independent settings presenter creates the settings window
- **THEN** the content size supports the redesigned category-and-detail layout without forcing the primary API key controls into a cramped single-column form

### Requirement: API key entry experience
The system SHALL provide polished, provider-aware API key entry controls that make secret entry understandable, accessible, and locally scoped.

#### Scenario: API key row has clear labels and state
- **WHEN** an API key setting is displayed
- **THEN** it includes a visible label that identifies the provider or feature
- **AND** it communicates whether the key is empty or saved locally
- **AND** it includes helper text that the key is stored only on this Mac through the current local settings storage

#### Scenario: API key visibility can be toggled
- **WHEN** an API key setting is displayed
- **THEN** the key is hidden by default
- **AND** the user can explicitly show or hide the key from the same row
- **AND** the show/hide control has an accessible name

#### Scenario: Provider context is preserved
- **WHEN** the user changes the Smart Input provider
- **THEN** the model picker updates using the existing provider catalog behavior
- **AND** the visible API key entry corresponds to the selected Smart Input provider

### Requirement: Shortcut recorder presentation
The system SHALL present global shortcut settings as consistent, readable rows while preserving the existing recorder behavior.

#### Scenario: Shortcut rows show current key and actions
- **WHEN** the shortcuts category renders
- **THEN** each shortcut row displays its current shortcut in a monospaced or keycap-like treatment
- **AND** each row provides an action to record a new shortcut
- **AND** each row provides an action to restore the default shortcut

#### Scenario: Recording state remains safe
- **WHEN** one shortcut recorder is waiting for a key press
- **THEN** other shortcut record actions are disabled
- **AND** pressing Esc cancels recording using the existing cancellation behavior
- **AND** modifier-key requirements remain unchanged

### Requirement: Settings accessibility and polish
The system SHALL keep settings controls accessible and visually polished across the redesigned settings window.

#### Scenario: Controls have accessible names
- **WHEN** the redesigned settings window renders icon-only or compact controls
- **THEN** each such control has an accessible name or visible text label
- **AND** keyboard focus order follows the visible category and detail layout

#### Scenario: Text hierarchy is readable
- **WHEN** the redesigned settings window renders helper copy, row labels, section titles, and status text
- **THEN** text uses a readable hierarchy with sufficient contrast
- **AND** helper text wraps instead of clipping inside its parent row

#### Scenario: Native behavior is preserved
- **WHEN** the user interacts with pickers, toggles, text fields, shortcut recording, Esc close, or window reopening
- **THEN** the existing business behavior remains unchanged
- **AND** the settings window still reuses `MalDazeSettingsView`

### Requirement: Dashboard Panel internal click stability
Dashboard Panel dismissal logic SHALL preserve the panel when the user clicks inside the Dashboard Panel content.

#### Scenario: Internal control click stays in panel
- **WHEN** the Dashboard Panel is visible
- **AND** the user clicks an interactive control inside the panel
- **THEN** the panel remains visible
- **AND** the clicked control handles the action normally

#### Scenario: Internal click during focus transition
- **WHEN** the Dashboard Panel is visible and the app processes a focus or activation transition
- **AND** the original mouse event location is inside the Dashboard Panel frame
- **THEN** click-away or app-deactivation dismissal does not hide the panel for that internal click

#### Scenario: Outside click still dismisses
- **WHEN** the Dashboard Panel is visible
- **AND** the user clicks outside both the Dashboard Panel and the desk-pet window
- **THEN** the panel closes or hides using the existing Dashboard Panel dismissal behavior

### Requirement: Dashboard reminder plan notes
The Dashboard left reminder plan sidebar SHALL display human-facing reminder notes when they are present.

#### Scenario: Reminder with notes
- **WHEN** the Dashboard left "计划" sidebar renders an incomplete reminder whose notes contain user-facing text
- **THEN** the reminder row displays the reminder title
- **AND** the row displays the user-facing notes as secondary detail text beneath the title
- **AND** the row still displays due-time and action controls

#### Scenario: Routine marker is hidden from notes
- **WHEN** a reminder note contains a standalone `#日常` marker line and additional user-facing text
- **THEN** the row displays the routine badge
- **AND** the row displays the additional user-facing text
- **AND** the row does not display the standalone `#日常` marker as note detail text

#### Scenario: Reminder without notes
- **WHEN** the Dashboard left "计划" sidebar renders a reminder without user-facing notes
- **THEN** the reminder row displays the title and due-time information without an empty detail line

### Requirement: Smart Input LLM provider settings
The system SHALL present Smart Input LLM credentials through a provider/model/API-key settings module.

#### Scenario: Dedicated LLM settings category
- **WHEN** the redesigned MalDaze settings window renders
- **THEN** the system presents a dedicated settings category for model and API key configuration
- **AND** the category contains Smart Input configuration
- **AND** the surface uses the provider picker, model picker, selected-provider API key row, saved/empty state, show/hide affordance, and local-only storage copy

#### Scenario: Feature-specific copy
- **WHEN** the Smart Input LLM settings surface renders
- **THEN** the surface communicates that it powers natural-language reminder parsing
- **AND** visual styling, spacing, button treatment, and pale-blue active accents remain consistent with the settings window

### Requirement: Smart Input provider selection
The system SHALL allow Smart Input reminder parsing to use Google Gemini, OpenAI, or DeepSeek.

#### Scenario: Smart Input supports the shared provider set
- **WHEN** the user configures Smart Input LLM settings
- **THEN** the provider picker offers Google Gemini, OpenAI, and DeepSeek
- **AND** the model picker shows the models for the selected Smart Input provider
- **AND** switching providers resets the Smart Input model to that provider's default model

#### Scenario: Smart Input selected-provider key
- **WHEN** the user selects a Smart Input provider
- **THEN** the API key row displays the selected provider's name and key label
- **AND** the key field reads and writes the selected provider's Smart Input API key storage
- **AND** the key remains hidden by default until the user explicitly shows it

#### Scenario: Existing Gemini Smart Input values remain usable
- **WHEN** the user has existing Smart Input Gemini settings from the previous Gemini-only implementation
- **THEN** Smart Input continues to resolve the existing Gemini API key and model for Gemini requests
- **AND** opening or using the new settings does not require the user to re-enter the existing Gemini key

### Requirement: Smart Input provider-aware runtime dispatch
The system SHALL dispatch Smart Input reminder parsing requests through the selected Smart Input provider and model.

#### Scenario: Smart Input request uses selected provider
- **WHEN** the user submits Smart Input text
- **THEN** the system resolves the Smart Input provider, model, and selected-provider API key at request time
- **AND** the reminder parsing request is sent through the selected provider client
- **AND** the provider response is normalized into the existing reminder JSON decoding flow

#### Scenario: Missing selected-provider key
- **WHEN** the selected Smart Input provider has no saved API key
- **THEN** the system does not create a reminder
- **AND** the user-facing error identifies the selected provider's API key as missing

#### Scenario: Smart Input provider changes take effect without restart
- **WHEN** the user changes Smart Input provider, model, or selected-provider API key in settings
- **THEN** the next Smart Input request uses the updated Smart Input configuration
- **AND** the app does not require restart for the Smart Input provider change
