# assistant-panel-ui Specification

## Purpose

MalDaze 菜单栏面板包含学习助手中栏。当前前端通过 SwiftUI 展示今日任务、资料进度、对话和添加资料入口，并通过 HTTP 调用本地 FastAPI 后端。

## Requirements

### Requirement: 三栏面板布局
系统 SHALL 在 MalDaze 面板中渲染左栏、学习助手中栏和右栏。

#### Scenario: 面板打开
- **WHEN** 用户点击桌宠打开面板
- **THEN** 面板包含左栏、中栏学习助手、右栏三个区域
- **AND** 中栏由 `AssistantPanelView` 渲染

### Requirement: 学习助手连接状态
学习助手中栏 SHALL 区分后端启动中和运行期离线状态。

#### Scenario: 后端启动中
- **WHEN** `LearningAssistantViewModel.isConnecting=true`
- **THEN** 中栏显示进度指示和“后端启动中…”提示

#### Scenario: 后端离线
- **WHEN** HTTP 请求失败并设置 `isOffline=true`
- **THEN** 中栏显示“助手离线”状态
- **AND** 提供重试按钮

#### Scenario: 后端就绪
- **WHEN** `BackendProcessManager` 发出 `backendDidBecomeReady` 通知
- **THEN** ViewModel 结束 connecting 状态
- **AND** 拉取今日简报

### Requirement: Tab 导航
学习助手中栏 SHALL 提供今日任务、资料进度、对话、添加资料四个 Tab。

#### Scenario: Tab 展示
- **WHEN** 后端已连接且未离线
- **THEN** 中栏显示 segmented picker
- **AND** 用户可切换四个 Tab

### Requirement: 今日任务视图
今日任务 Tab SHALL 展示今日简报与任务列表。

#### Scenario: 摘要展示
- **WHEN** 今日简报包含 highlights 或 total_minutes
- **THEN** 视图显示“今日目标”、总分钟数和 highlights

#### Scenario: 任务列表
- **WHEN** `tasks` 非空
- **THEN** 视图逐条展示任务标题、资料名、目标分钟、完成状态和 P1 标记

#### Scenario: 标记完成
- **WHEN** 用户点击未完成任务的完成按钮
- **THEN** 前端调用 `POST /api/tasks/{id}/complete`
- **AND** 完成后重新拉取今日简报

#### Scenario: 今日无任务
- **WHEN** `tasks` 为空
- **THEN** 视图显示今日暂无学习任务的空状态提示

### Requirement: 资料进度视图
资料进度 Tab SHALL 展示 active 资料的进度概览。

#### Scenario: 拉取资料
- **WHEN** 用户进入资料进度 Tab
- **THEN** 前端调用 `/api/resources`

#### Scenario: 资料卡片
- **WHEN** resources 非空
- **THEN** 每项显示资料标题、进度条、completed_units/total_units、累计投入时间、deadline 和 status badge

#### Scenario: 无资料
- **WHEN** resources 为空
- **THEN** 视图显示暂无资料记录

### Requirement: 对话视图
对话 Tab SHALL 支持发送消息、展示回复和确认计划变更提案。

#### Scenario: 发送消息
- **WHEN** 用户输入文本并按 Enter 或点击发送按钮
- **THEN** 前端追加用户消息
- **AND** 调用 `POST /api/chat`

#### Scenario: 文字回复
- **WHEN** 后端返回 response
- **THEN** 前端追加助手消息

#### Scenario: 提案回复
- **WHEN** 后端返回 proposal
- **THEN** 前端展示 proposal summary
- **AND** 显示确认与取消按钮

#### Scenario: 确认提案
- **WHEN** 用户点击确认
- **THEN** 前端调用 `POST /api/chat/confirm`
- **AND** 清空当前提案
- **AND** 刷新今日简报

### Requirement: 添加资料视图
添加资料 Tab SHALL 支持输入 URL、deadline 和 speed_factor，展示导入草稿并确认或取消。

#### Scenario: 开始分析
- **WHEN** 用户输入 URL 并点击分析
- **THEN** 前端调用 `POST /api/ingest`
- **AND** 分析期间显示 loading 状态

#### Scenario: 展示草稿
- **WHEN** 后端返回 ingestion draft
- **THEN** 前端显示资料标题、unit 数、总估算小时数和方案 A/B 选择器

#### Scenario: 确认草稿
- **WHEN** 用户点击确认写入
- **THEN** 前端调用 `POST /api/ingest/confirm`，传入 selected_option
- **AND** 成功后清空草稿并刷新今日简报

#### Scenario: 取消草稿
- **WHEN** 用户点击取消
- **THEN** 前端调用 `POST /api/ingest/confirm` 且 confirmed=false
- **AND** 清空草稿

### Requirement: HTTP 客户端
Swift 前端 SHALL 通过 `AssistantAPIClient` 调用本地后端。

#### Scenario: 请求超时配置
- **WHEN** 前端发起请求
- **THEN** request timeout 为 120 秒
- **AND** resource timeout 为 300 秒

#### Scenario: 解码失败
- **WHEN** 响应 JSON 与 Swift 模型不匹配
- **THEN** 当前实现将错误转换为 `AssistantOfflineError`
