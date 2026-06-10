## MODIFIED Requirements

### Requirement: 浮层展示
系统 SHALL 在菜单栏所在屏幕的可见区域中央展示喝水提醒浮层 without activating MalDaze or foregrounding unrelated MalDaze windows.

#### Scenario: 浮层触发
- **WHEN** Timer 到点且不处于安静时段
- **THEN** 系统显示一个 `.screenSaver` 层级的 borderless non-activating panel
- **AND** 窗口可跨 Space 显示
- **AND** 浮层包含水滴图标、随机喝水文案、“已喝水 💧”主按钮和“稍后提醒”次按钮

#### Scenario: 不激活应用
- **WHEN** 浮层显示
- **THEN** 系统 does not call `NSApp.activate(ignoringOtherApps: true)`
- **AND** 调用 `orderFrontRegardless()`
- **AND** an already-visible desk-pet Dashboard remains in its prior z-order relative to other applications

#### Scenario: 屏幕配置变化
- **WHEN** 浮层可见且屏幕参数变化
- **THEN** 系统按当前菜单栏屏幕重新居中浮层
