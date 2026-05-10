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
控制面板 SHALL 提供手动番茄和整点/半点模式控制。

#### Scenario: 模式切换
- **WHEN** 用户切换模式
- **THEN** 系统停止当前引擎
- **AND** 关闭休息窗口
- **AND** 按新模式更新状态行和宠物状态

#### Scenario: 手动专注
- **WHEN** 用户在手动模式点击“开始专注”
- **THEN** 系统启动 manual timer
- **AND** 设置计时会话 active

#### Scenario: 停止计时
- **WHEN** 用户点击“停止计时”
- **THEN** 系统停止当前计时引擎
- **AND** 显示“恢复计时”入口

#### Scenario: 恢复计时
- **WHEN** 用户点击“恢复计时”
- **THEN** 系统按当前模式重新启动对应计时引擎

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
