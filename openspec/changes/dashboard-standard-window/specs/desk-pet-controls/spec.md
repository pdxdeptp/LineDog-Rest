## ADDED Requirements

### Requirement: Dashboard window frame persistence
MalDaze SHALL persist the desk pet Dashboard window frame across launches and SHALL restore that frame whenever the Dashboard window is shown from the Dock icon, desk pet left-click, or the desk pet menu global shortcut.

#### Scenario: Restore saved frame on open
- **WHEN** the user opens the Dashboard window and persisted frame values exist
- **THEN** MalDaze places the Dashboard window at the saved origin and size
- **AND** clamps the frame into the current visible screen area if needed

#### Scenario: Save frame after move or resize
- **WHEN** the user moves or resizes the visible Dashboard window
- **THEN** MalDaze persists the updated origin and size to `UserDefaults`

#### Scenario: First launch without saved frame
- **WHEN** the Dashboard window is shown for the first time and no persisted frame exists
- **THEN** MalDaze centers the Dashboard window within the primary screen visible frame using the dashboard preferred content size

### Requirement: Dashboard Dock icon entry
MalDaze SHALL treat the Dock application icon as a first-class entry point for the desk pet Dashboard window within the same application.

#### Scenario: Dock click opens or focuses Dashboard
- **WHEN** the user clicks the MalDaze Dock icon while the application is already running
- **THEN** MalDaze activates the application
- **AND** shows or focuses the Dashboard window at the persisted frame
- **AND** does not use Dock reopen solely to bring the idle desk pet window to the front

#### Scenario: Dashboard focus from Dock when already visible
- **WHEN** the Dashboard window is already visible and the user clicks the MalDaze Dock icon while another application is frontmost
- **THEN** MalDaze activates the application
- **AND** brings the existing Dashboard window to the front without hiding it

### Requirement: Dashboard window during rest fullscreen
MalDaze SHALL keep the Dashboard window open when the desk pet enters fullscreen rest presentation and SHALL NOT auto-close the Dashboard window as part of starting rest.

#### Scenario: Rest starts with Dashboard open
- **WHEN** the desk pet enters fullscreen rest while the Dashboard window is visible
- **THEN** the Dashboard window remains open and hidden only by window z-order beneath the rest presentation
- **AND** MalDaze does not call dashboard hide logic solely because rest started

#### Scenario: Dashboard returns after rest ends
- **WHEN** fullscreen rest ends and the Dashboard window had been open before rest
- **THEN** the Dashboard window becomes visible again at its persisted frame without requiring the user to reopen it

## MODIFIED Requirements

### Requirement: Dashboard Panel presentation
桌宠 Dashboard SHALL present as a standard MalDaze `NSWindow` hosted by `DeskPetDashboardView`, replacing the prior floating `NSPanel` presentation.

#### Scenario: Window creation
- **WHEN** 桌宠 Dashboard 首次需要显示
- **THEN** 系统创建 `NSWindow` 或等价 `NSWindow` 子类
- **AND** 窗口背景允许 SwiftUI root view 绘制自己的圆角、材质和阴影
- **AND** 窗口使用常规 managed collection behavior，以便 Mission Control 与同一应用内窗口切换可见
- **AND** 窗口具有稳定 identifier 供 `WindowManager` 与 `NSApplicationDelegate` 前置

#### Scenario: Key window behavior
- **WHEN** Dashboard 中存在文本输入、按钮或 SwiftUI 控件
- **THEN** 窗口支持成为 key window
- **AND** 用户可以正常输入文本并操作控件

#### Scenario: Repeat presentation
- **WHEN** Dashboard 已经创建且用户再次从桌宠入口、Dock 入口或全局快捷键打开
- **THEN** 系统复用既有窗口 和 SwiftUI host
- **AND** 不因重复打开而重新冷创建整个 dashboard 视图树

### Requirement: Dashboard Panel dismissal
系统 SHALL 使用显式逻辑关闭或隐藏桌宠 Dashboard 窗口，且 SHALL NOT 因外部点击或应用失活而自动关闭。

#### Scenario: 再次点击桌宠
- **WHEN** Dashboard 已经打开且用户再次触发桌宠打开动作
- **THEN** 系统关闭或隐藏该 Dashboard 窗口

#### Scenario: Esc
- **WHEN** Dashboard 打开且用户按 Esc
- **THEN** 系统先由 `DeskPetDashboardEscapeRouter` 关闭已登记的 sheet 或对话框（若存在）
- **AND** 若无登记 overlay，则关闭或隐藏 Dashboard 窗口

#### Scenario: 显式关闭
- **WHEN** 用户通过窗口关闭控件或等价显式关闭动作（如 Cmd+W）关闭 Dashboard
- **THEN** 系统隐藏 Dashboard 窗口
- **AND** 保留 dashboard 本地 UI 状态供下次打开

#### Scenario: State preservation on hide
- **WHEN** 系统隐藏 Dashboard 窗口
- **THEN** 系统保留 dashboard 本地 UI 状态和草稿状态
- **AND** 下一次打开可恢复仍然有效的本地状态

### Requirement: 宽屏桌宠 Dashboard Panel
桌宠 Dashboard SHALL 使用接近当前屏幕可见宽度的横向布局，并将中间主内容区域设为自适应区域。

#### Scenario: 桌宠入口打开宽屏 Dashboard Panel
- **WHEN** 用户左键点击常态桌宠命中区打开 Dashboard
- **THEN** 系统显示 dashboard root view
- **AND** 窗口横向宽度接近当前屏幕可见宽度并保留安全边距
- **AND** 窗口不超过当前屏幕可见区域

#### Scenario: 左右栏固定宽度
- **WHEN** Dashboard 计算三栏布局
- **THEN** 左侧提醒栏保持固定宽度
- **AND** 右侧控制栏保持固定宽度
- **AND** 分隔线和外边距保持固定宽度

#### Scenario: 主内容区域自适应
- **WHEN** 当前屏幕可见宽度大于三栏最小宽度
- **THEN** 中间主内容区域获得左右栏之外的剩余宽度
- **AND** 主内容区域宽度随屏幕宽度增加而增加

#### Scenario: 窄屏降级
- **WHEN** 当前屏幕可见宽度不足以展示目标宽屏宽度
- **THEN** 窗口宽度被 clamp 到当前屏幕可见区域内
- **AND** 中间主内容区域保持最小可读宽度

#### Scenario: Panel position
- **WHEN** 用户从桌宠入口打开 Dashboard
- **THEN** 系统显示或聚焦 Dashboard 于 persisted frame
- **AND** 不因桌宠当前屏幕位置重新锚定窗口

### Requirement: Dashboard Panel internal click stability
Dashboard 交互 SHALL 在用户点击 Dashboard 内容时保持窗口可见，且 SHALL NOT 因焦点切换或外部点击而自动隐藏。

#### Scenario: Internal control click stays in panel
- **WHEN** the Dashboard window is visible
- **AND** the user clicks an interactive control inside the window
- **THEN** the window remains visible
- **AND** the clicked control handles the action normally

#### Scenario: Internal click during focus transition
- **WHEN** the Dashboard window is visible and the app processes a focus or activation transition
- **AND** the original mouse event location is inside the Dashboard window frame
- **THEN** the window remains visible for that internal interaction

#### Scenario: Outside click does not dismiss
- **WHEN** the Dashboard window is visible
- **AND** the user clicks outside both the Dashboard window and the desk-pet window
- **THEN** the Dashboard window remains visible
