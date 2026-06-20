## MODIFIED Requirements

### Requirement: 浮层展示
系统 SHALL 通过 `MalDazeTransientOverlayPresenter` 在菜单栏所在屏幕的可见区域中央展示喝水提醒浮层，且 MUST NOT 在 `HydrationReminderController` 内维护独立 `NSPanel` 生命周期。

#### Scenario: 浮层触发
- **WHEN** Timer 到点且不处于安静时段
- **THEN** `HydrationReminderController` 委托展示器显示被动型浮层
- **AND** 浮层为 `.screenSaver` 层级的 borderless non-activating `NSPanel`
- **AND** 窗口可跨 Space 显示
- **AND** 浮层包含水滴图标、随机喝水文案、“已喝水 💧”主按钮和“稍后提醒”次按钮

#### Scenario: 不激活应用且保持 Dashboard 层级
- **WHEN** 浮层显示
- **THEN** 系统 does not call `NSApp.activate(ignoringOtherApps: true)`
- **AND** 展示器调用 `orderFrontRegardless()` 使浮层位于最前
- **AND** 若 MalDaze 在展示前未激活且 Dashboard 已可见，Dashboard 相对其他 App 的层级保持不变

#### Scenario: 屏幕配置变化
- **WHEN** 浮层可见且屏幕参数变化
- **THEN** 展示器按当前菜单栏屏幕重新居中浮层

## MODIFIED Requirements

### Requirement: 浮层操作
系统 SHALL 根据用户选择关闭浮层并重新调度；浮层关闭 MUST 经展示器执行，且 MUST NOT 因关闭动作激活 MalDaze 或抬高 Dashboard。

#### Scenario: 已喝水
- **WHEN** 用户点击“已喝水 💧”
- **THEN** 展示器关闭浮层
- **AND** `HydrationReminderController` 按完整配置间隔重新调度

#### Scenario: 稍后提醒
- **WHEN** 用户点击“稍后提醒”
- **THEN** 展示器关闭浮层
- **AND** `HydrationReminderController` 按 15 分钟重新调度
