## MODIFIED Requirements

### Requirement: 学习助手连接状态
学习助手中栏 SHALL 区分后端启动中、服务不可用和后端就绪状态，并 SHALL respect the user's configured assistant backend startup mode.

#### Scenario: 后端启动中
- **WHEN** `LearningAssistantViewModel.isConnecting=true`
- **THEN** 中栏显示进度指示和”后端启动中…”提示
- **AND** 不将启动等待描述为错误或离线

#### Scenario: 服务不可用
- **WHEN** HTTP 请求失败并设置 `isOffline=true`
- **THEN** 整个学习助手中栏显示”助手离线”或等价服务不可用状态
- **AND** 提供重试按钮
- **AND** 不显示旧首页内容、局部失败内容或底部导航

#### Scenario: 后端就绪
- **WHEN** `BackendProcessManager` 发出 `backendDidBecomeReady` 通知
- **THEN** ViewModel 结束 connecting 状态
- **AND** 拉取首页所需的今日简报和资料状态

#### Scenario: 用户选择懒启动后端
- **GIVEN** 用户启用助手后端懒启动
- **WHEN** 应用启动但用户尚未打开学习助手中栏
- **THEN** 系统 MUST NOT spawn the local assistant backend process solely because the app launched

#### Scenario: 用户选择随 App 启动后端
- **GIVEN** 用户关闭助手后端懒启动
- **WHEN** 应用启动完成
- **THEN** 系统 SHALL request local assistant backend startup idempotently

#### Scenario: 懒启动模式下打开助手后请求后端
- **GIVEN** 用户启用助手后端懒启动
- **WHEN** 学习助手中栏 ViewModel 被创建或开始加载首页数据
- **THEN** 系统 SHALL request backend startup if it is not already ready or starting
- **AND** the existing connecting, offline, and ready UI states SHALL remain accurate

#### Scenario: 设置页展示启动策略
- **WHEN** 用户打开设置页
- **THEN** 系统 SHALL expose a persistent setting that controls whether the assistant backend starts lazily
- **AND** the setting label or help text SHALL communicate the energy/latency trade-off
