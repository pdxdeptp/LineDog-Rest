## MODIFIED Requirements

### Requirement: 共享控制面板
系统 SHALL 从桌宠入口显示专用 Dashboard Panel。该 Dashboard Panel SHALL 承载桌宠综合控制面板能力，并 SHALL 不要求菜单栏入口复用同一套面板。

#### Scenario: 菜单栏入口
- **WHEN** 用户打开菜单栏 Extra
- **THEN** 系统 SHALL NOT 因桌宠 Dashboard Panel 要求而显示桌宠综合控制面板

#### Scenario: 桌宠入口
- **WHEN** 用户左键点击常态桌宠命中区
- **THEN** 系统在桌宠附近显示 Dashboard Panel
- **AND** Dashboard Panel 的 root view 渲染提醒事项、学习助手和桌宠/计时控制区域
- **AND** Dashboard Panel 使用 `NSPanel` 或等价 `NSPanel` 子类承载

#### Scenario: 全局快捷键入口
- **WHEN** 系统收到 `presentDeskPetMenu` 通知
- **THEN** `WindowManager` 以桌宠命中区为 anchor 打开同一个 Dashboard Panel

## ADDED Requirements

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
桌宠 Dashboard Panel SHALL 使用接近当前屏幕可见宽度的横向布局，并将中间学习助手栏设为自适应主区域。

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

#### Scenario: 学习助手栏自适应
- **WHEN** 当前屏幕可见宽度大于三栏最小宽度
- **THEN** 中间学习助手栏获得左右栏之外的剩余宽度
- **AND** 学习助手栏宽度随屏幕宽度增加而增加

#### Scenario: 窄屏降级
- **WHEN** 当前屏幕可见宽度不足以展示目标宽屏宽度
- **THEN** panel 宽度被 clamp 到当前屏幕可见区域内
- **AND** 学习助手栏保持最小可读宽度

#### Scenario: Panel position
- **WHEN** Dashboard Panel 从桌宠入口打开
- **THEN** 系统优先将 panel 放置在桌宠附近
- **AND** 若桌宠位置会导致 panel 超出可见区域，系统将 panel 移入当前屏幕可见区域

## REMOVED Requirements

### Requirement: Popover dismiss
**Reason**: The desk pet dashboard no longer uses `NSPopover`, so popover-specific dismiss behavior is replaced by Dashboard Panel dismissal behavior.

**Migration**: Use `Dashboard Panel dismissal` for desk pet panel close behavior.

### Requirement: 宽屏桌宠菜单 popover
**Reason**: The wide control surface is now a Dashboard Panel rather than an `NSPopover`.

**Migration**: Use `宽屏桌宠 Dashboard Panel` for layout, positioning, and close behavior.
