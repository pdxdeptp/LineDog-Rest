## MODIFIED Requirements

### Requirement: 学习助手连接状态
学习助手中栏 SHALL 区分后端启动中、服务不可用、后端就绪和已缓存内容刷新中状态。

#### Scenario: 后端启动中且无缓存内容
- **WHEN** `LearningAssistantViewModel.isConnecting=true`
- **AND** 没有可展示的已缓存 dashboard 内容
- **THEN** 中栏显示进度指示和”后端启动中…”提示
- **AND** 不将启动等待描述为错误或离线

#### Scenario: 后端启动中且有缓存内容
- **WHEN** `LearningAssistantViewModel.isConnecting=true`
- **AND** 存在可展示的已缓存 dashboard 内容
- **THEN** 中栏继续显示已缓存 dashboard 内容
- **AND** 通过小型加载反馈表示后台刷新或连接恢复中
- **AND** 不强制整栏切换为灰色启动占位

#### Scenario: 服务不可用
- **WHEN** HTTP 请求失败并设置 `isOffline=true`
- **THEN** 整个学习助手中栏显示”助手离线”或等价服务不可用状态
- **AND** 提供重试按钮
- **AND** 不显示旧首页内容、局部失败内容或底部导航

#### Scenario: 后端就绪
- **WHEN** `BackendProcessManager` 发出 `backendDidBecomeReady` 通知
- **THEN** ViewModel 结束 connecting 状态
- **AND** 拉取首页所需的今日简报和资料状态

## ADDED Requirements

### Requirement: Dashboard Panel hosted learning assistant state
学习助手中栏 SHALL support being hosted inside a long-lived desk pet Dashboard Panel.

#### Scenario: Panel hidden
- **WHEN** 用户关闭或隐藏 Dashboard Panel
- **THEN** 学习助手本地 UI 状态保持可恢复
- **AND** 已选择的学习助手 tab、可恢复草稿、任务展开状态和已加载 dashboard 数据不因 panel 隐藏而被主动清空

#### Scenario: Panel reopened with loaded data
- **WHEN** 用户重新打开 Dashboard Panel
- **AND** 学习助手已有有效的本地 dashboard 数据
- **THEN** 中栏立即显示该 dashboard 数据
- **AND** 系统在后台刷新今日简报和资料状态

#### Scenario: Background refresh feedback
- **WHEN** Dashboard Panel 使用缓存内容并正在刷新
- **THEN** 学习助手中栏显示非阻塞刷新反馈
- **AND** 用户仍可查看已缓存内容

#### Scenario: First open without loaded data
- **WHEN** 用户首次打开 Dashboard Panel
- **AND** 学习助手没有可展示的本地 dashboard 数据
- **THEN** 中栏使用现有后端启动中、空数据库、任务列表或离线状态规则渲染
