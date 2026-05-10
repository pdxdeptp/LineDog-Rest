# hydration-reminder Specification

## Purpose

MalDaze 提供独立喝水提醒层。它由 Swift/AppKit 控制器调度，不经过 `WindowManager`，通过菜单栏/桌宠共享控制面板启停和配置。

## Requirements

### Requirement: 启停与状态同步
系统 SHALL 通过 `AppViewModel` 持有 `HydrationReminderController`，并将启停状态持久化到 UserDefaults。

#### Scenario: 开启喝水提醒
- **WHEN** 用户打开“开启喝水提醒”开关
- **THEN** 系统写入 `MalDaze.hydrationReminder.enabled=true`
- **AND** 调用 `HydrationReminderController.start()`
- **AND** `isHydrationReminderEnabled` 变为 true

#### Scenario: 关闭喝水提醒
- **WHEN** 用户关闭“开启喝水提醒”开关
- **THEN** 系统写入 `MalDaze.hydrationReminder.enabled=false`
- **AND** 取消待触发 Timer
- **AND** 关闭当前喝水提醒浮层
- **AND** `isHydrationReminderEnabled` 变为 false

#### Scenario: 应用启动恢复
- **WHEN** 应用启动且 UserDefaults 中喝水提醒开关为 true
- **THEN** `AppViewModel` 自动启动 `HydrationReminderController`

### Requirement: 间隔配置
系统 SHALL 支持用户配置喝水提醒间隔，范围为 15 到 240 分钟。

#### Scenario: 默认间隔
- **WHEN** UserDefaults 中未写入有效间隔，或存储值小于 15
- **THEN** 系统使用 90 分钟作为默认间隔

#### Scenario: 修改间隔
- **WHEN** 用户通过 Stepper 修改间隔
- **THEN** 系统将数值 clamp 到 15...240
- **AND** 写入 `MalDaze.hydrationReminder.intervalMinutes`

#### Scenario: 开启状态下修改间隔
- **WHEN** 喝水提醒已开启且用户提交新的间隔
- **THEN** 系统取消当前调度
- **AND** 按新间隔重新调度下一次提醒

### Requirement: 单次 Timer 调度
系统 SHALL 使用单次 Timer 调度下一次喝水提醒，而不是 repeating timer。

#### Scenario: start 调度
- **WHEN** `start()` 被调用
- **THEN** 系统先取消旧 Timer 和旧浮层
- **AND** 按当前配置间隔创建新的单次 Timer

#### Scenario: cancel 清理
- **WHEN** `cancel()` 被调用
- **THEN** 系统 invalidate `pendingTimer`
- **AND** 清空 `pendingTimer`
- **AND** 移除屏幕变化观察者

### Requirement: 安静时段
系统 SHALL 支持可选安静时段，在该时段内不弹出喝水浮层。

#### Scenario: 安静时段默认值
- **WHEN** 安静时段时间未配置
- **THEN** 默认停止时间为 21:00
- **AND** 默认恢复时间为 08:00

#### Scenario: 安静时段内触发
- **WHEN** Timer 到点且当前处于安静时段
- **THEN** 系统不显示浮层
- **AND** 重新调度到恢复时间

#### Scenario: 跨日安静时段
- **WHEN** 停止时间晚于恢复时间，例如 21:00 到 08:00
- **THEN** 当前分钟数大于等于停止时间或小于恢复时间时视为安静时段

#### Scenario: 同日安静时段
- **WHEN** 停止时间早于恢复时间
- **THEN** 当前分钟数在停止时间和恢复时间之间时视为安静时段

### Requirement: 浮层展示
系统 SHALL 在菜单栏所在屏幕的可见区域中央展示喝水提醒浮层。

#### Scenario: 浮层触发
- **WHEN** Timer 到点且不处于安静时段
- **THEN** 系统显示一个 `.screenSaver` 层级的 borderless `NSWindow`
- **AND** 窗口可跨 Space 显示
- **AND** 浮层包含水滴图标、随机喝水文案、“已喝水 💧”主按钮和“稍后提醒”次按钮

#### Scenario: 激活应用
- **WHEN** 浮层显示
- **THEN** 系统调用 `NSApp.activate(ignoringOtherApps: true)`
- **AND** 调用 `orderFrontRegardless()`

#### Scenario: 屏幕配置变化
- **WHEN** 浮层可见且屏幕参数变化
- **THEN** 系统按当前菜单栏屏幕重新居中浮层

### Requirement: 浮层操作
系统 SHALL 根据用户选择关闭浮层并重新调度。

#### Scenario: 已喝水
- **WHEN** 用户点击“已喝水 💧”
- **THEN** 系统关闭浮层
- **AND** 移除屏幕变化观察者
- **AND** 按完整配置间隔重新调度

#### Scenario: 稍后提醒
- **WHEN** 用户点击“稍后提醒”
- **THEN** 系统关闭浮层
- **AND** 移除屏幕变化观察者
- **AND** 按 15 分钟重新调度

### Requirement: 测试触发
系统 SHALL 提供控制面板测试入口立即显示喝水提醒。

#### Scenario: 立即触发
- **WHEN** 用户点击“立即触发（测试）”
- **THEN** 系统调用 `testing_fireNow()`
- **AND** 本次触发绕过安静时段判断

### Requirement: 控制面板配置
系统 SHALL 在菜单栏和桌宠共享控制面板中展示喝水提醒设置。

#### Scenario: 控件展示
- **WHEN** 用户打开控制面板
- **THEN** 喝水提醒区块显示启停开关、间隔 Stepper、安静时段开关、停止时间、恢复时间、立即触发按钮和说明文案

#### Scenario: 禁用联动
- **WHEN** 喝水提醒关闭
- **THEN** 间隔、安静时段和时间选择控件不可用
