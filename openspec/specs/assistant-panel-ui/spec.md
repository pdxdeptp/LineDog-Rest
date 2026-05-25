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

### Requirement: Tab 导航
学习助手中栏 SHALL 以首页 dashboard 作为后端就绪后的默认入口，并 SHALL 使用底部固定导航提供首页、添加资料、资料进度和调整计划入口。

#### Scenario: 后端就绪后的默认入口
- **WHEN** 后端已连接且未离线
- **THEN** 中栏默认显示学习助手首页 dashboard
- **AND** 首页优先展示今日摘要、任务数量、总分钟数和资料风险
- **AND** 不将某一项任务作为系统推荐的下一步主行动

#### Scenario: 底部固定导航
- **WHEN** 中栏显示首页或任一学习助手工具页
- **THEN** 底部导航显示首页、添加资料、资料进度和调整计划入口
- **AND** 底部导航固定在学习助手中栏底部
- **AND** 上方首页信息流滚动时底部导航仍保持可见

#### Scenario: 进入次级工具
- **WHEN** 用户点击底部导航中的添加资料、资料进度或调整计划
- **THEN** 中栏切换到对应功能界面
- **AND** 用户可通过底部导航回到首页

#### Scenario: 导航降噪
- **WHEN** 首页首次渲染
- **THEN** 今日任务、资料进度、对话和添加资料不作为四个同等优先级的第一屏内容平铺展示

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
资料进度 Tab SHALL 展示 active 资料的进度概览，并 SHALL 提供可直接执行或进入既有计划调整流程的资料管理动作。

#### Scenario: 拉取资料
- **WHEN** 用户进入资料进度 Tab
- **THEN** 前端调用 `/api/resources`

#### Scenario: 资料卡片
- **WHEN** resources 非空
- **THEN** 每项显示资料标题、进度条、completed_units/total_units、累计投入时间、deadline 和 status badge
- **AND** 每项提供资料管理动作入口

#### Scenario: 打开资料链接
- **WHEN** 某资料包含有效 `url`
- **THEN** 资料卡片显示打开资料动作
- **AND** 用户触发该动作时系统打开该 `url`

#### Scenario: 无资料链接
- **WHEN** 某资料没有有效 `url`
- **THEN** 资料卡片不显示可点击的打开资料动作或显示不可用状态
- **AND** 前端不伪造或猜测跳转 URL

#### Scenario: 按资料调整计划
- **WHEN** 用户在某资料卡片选择调整计划
- **THEN** 中栏切换到调整计划视图
- **AND** 对话输入框预填包含该资料标题的计划调整提示
- **AND** 用户可编辑提示后再发送

#### Scenario: 标记资料完成
- **WHEN** 用户在某资料卡片确认标记完成
- **THEN** 前端调用资料完成 API
- **AND** 成功后重新拉取首页 dashboard 和资料列表

#### Scenario: 移出当前计划
- **WHEN** 用户在某资料卡片确认移出当前计划
- **THEN** 前端调用资料归档 API
- **AND** 成功后重新拉取首页 dashboard 和资料列表

#### Scenario: 管理动作失败
- **WHEN** 资料完成或归档 API 调用失败
- **THEN** 资料进度视图显示明确失败反馈
- **AND** 不从本地列表中移除该资料

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
- **THEN** 前端调用 `POST /api/ingest/start` 获取 `thread_id`
- **AND** 订阅 `GET /api/ingest/progress/{thread_id}` SSE 展示阶段进度

#### Scenario: 展示草稿
- **WHEN** SSE 返回 `draft_ready` 且携带 draft
- **THEN** 前端显示资料标题、unit 数、总估算小时数和方案 A/B 选择器

#### Scenario: 确认草稿
- **WHEN** 用户点击确认写入
- **THEN** 前端调用 `POST /api/ingest/confirm`，传入 selected_option 及可选 deadline/speed_factor
- **AND** 成功后清空草稿并刷新今日简报

#### Scenario: 取消草稿
- **WHEN** 用户点击取消（本地取消草稿）
- **THEN** 前端清除草稿 UI 状态且不写入数据库；可选调用 `POST /api/ingest/confirm` 且 `confirmed=false` 以保持契约一致

### Requirement: HTTP 客户端
Swift 前端 SHALL 通过 `AssistantAPIClient` 调用本地后端。

#### Scenario: 请求超时配置
- **WHEN** 前端发起请求
- **THEN** request timeout 为 120 秒
- **AND** resource timeout 为 300 秒

#### Scenario: 解码失败
- **WHEN** 响应 JSON 与 Swift 模型不匹配
- **THEN** 当前实现将错误转换为 `AssistantOfflineError`

### Requirement: 学习助手首页 dashboard
学习助手首页 SHALL 在一屏内回答今日整体学习状态，并让用户自主选择任务顺序。

#### Scenario: 有今日未完成任务
- **WHEN** 今日简报包含未完成任务
- **THEN** 首页显示今日总分钟数、任务数量、今日 highlights 和任务列表
- **AND** 任务列表允许用户自行选择先学习哪一项

#### Scenario: 今日任务全部完成
- **WHEN** 今日简报中的任务均已完成
- **THEN** 首页显示今日已完成状态
- **AND** 底部导航仍允许用户进入资料进度、添加资料或调整计划

#### Scenario: 今日无任务但已有资料
- **WHEN** 今日简报 tasks 为空
- **AND** `/api/resources` 返回至少一条资料
- **THEN** 首页说明今天没有安排学习任务
- **AND** 提供进入资料进度和调整计划的底部导航入口

#### Scenario: 空数据库
- **WHEN** 今日简报 tasks 为空
- **AND** `/api/resources` 返回空数组
- **THEN** 首页说明尚未添加学习资料
- **AND** 添加第一份资料是首页主行动

#### Scenario: deadline 风险
- **WHEN** 资料状态或 deadline 字段表明存在临近截止或逾期风险
- **THEN** 首页在今日摘要区域显示风险提示
- **AND** 提供进入资料进度的入口查看详情

### Requirement: 首页任务列表操作
首页任务列表 SHALL 支持展示顺序调整、轻量详情展开、完成操作和学习链接跳转。

#### Scenario: 拖拽调整展示顺序
- **WHEN** 用户拖动今日任务行的排序把手
- **THEN** 前端调整当前首页任务列表的展示顺序
- **AND** 不调用后端修改 task priority、scheduled_date 或 Morning Agent 排期

#### Scenario: 刷新后保留本地展示顺序
- **WHEN** 用户调整今日任务展示顺序后刷新首页
- **THEN** 前端在任务 id 集合仍匹配时恢复该展示顺序
- **AND** 若任务集合变化，前端保留仍存在任务的相对顺序并追加新任务

#### Scenario: 点击任务展开详情
- **WHEN** 用户点击任务行主体
- **THEN** 任务行展开或折叠轻量详情
- **AND** 详情展示任务所属资料、目标分钟和学习链接入口状态

#### Scenario: 打开学习链接
- **WHEN** 展开的任务详情存在 `unit_url` 或 `resource_url`
- **THEN** 前端显示明确的"打开链接"动作
- **AND** 用户点击后系统打开 `unit_url`，若不存在则打开 `resource_url`

#### Scenario: 无学习链接
- **WHEN** 展开的任务详情没有 `unit_url` 且没有 `resource_url`
- **THEN** 前端显示链接不可用状态
- **AND** 不伪造或猜测跳转 URL

#### Scenario: 标记完成
- **WHEN** 用户点击未完成任务的完成按钮
- **THEN** 前端调用 `POST /api/tasks/{id}/complete`
- **AND** 完成后重新拉取今日简报

### Requirement: 首页数据聚合与刷新
学习助手首页 SHALL 优先通过现有 API 聚合今日简报与资料状态。

#### Scenario: 首页首次加载
- **WHEN** 后端就绪后首页首次加载
- **THEN** 前端调用 `GET /api/today-briefing`
- **AND** 前端调用 `GET /api/resources`
- **AND** 首页根据两个响应组合展示 dashboard 状态

#### Scenario: 刷新首页
- **WHEN** 用户点击首页刷新入口
- **THEN** 前端重新拉取今日简报和资料状态
- **AND** 刷新期间显示加载反馈

#### Scenario: 任一首页请求失败
- **WHEN** 首页加载所需的今日简报或资料状态请求失败
- **THEN** 前端进入整栏服务不可用状态
- **AND** 不展示局部失败 dashboard

### Requirement: 首页前端验收状态
学习助手首页 SHALL 提供可测试的 fixture 或等价状态构造，以覆盖关键视觉与交互状态。

#### Scenario: 空数据库验收
- **WHEN** 测试 fixture 提供空今日简报和空资料列表
- **THEN** 首页呈现空数据库状态
- **AND** 添加第一份资料入口为主要行动

#### Scenario: 后端启动中验收
- **WHEN** 测试 fixture 设置 `isConnecting=true`
- **THEN** 首页呈现后端启动中状态

#### Scenario: 后端离线验收
- **WHEN** 测试 fixture 设置离线状态
- **THEN** 整个学习助手中栏呈现服务不可用状态和重试入口
- **AND** 不显示底部导航

#### Scenario: 有今日任务验收
- **WHEN** 测试 fixture 提供至少一个未完成任务
- **THEN** 首页呈现今日总分钟数、今日摘要和任务列表

#### Scenario: 任务详情与链接验收
- **WHEN** 测试 fixture 提供带 `resource_url` 的任务
- **THEN** 用户可展开任务详情
- **AND** 详情显示打开链接动作

#### Scenario: 任务排序验收
- **WHEN** 测试 fixture 提供多条今日任务
- **THEN** 用户可拖拽调整展示顺序
- **AND** 刷新后前端恢复可匹配任务的本地展示顺序

#### Scenario: 底部导航验收
- **WHEN** 首页内容高度超过中栏可视高度
- **THEN** 用户滚动首页信息流时底部导航保持可见

#### Scenario: 有资料但今日无任务验收
- **WHEN** 测试 fixture 提供空今日任务和至少一个资料
- **THEN** 首页呈现已有资料但今日无任务状态

#### Scenario: deadline 风险验收
- **WHEN** 测试 fixture 提供临近截止或逾期资料
- **THEN** 首页呈现 deadline 风险提示

### Requirement: 学习偏好入口
学习助手中栏 SHALL 提供进入学习偏好设置页的入口。

#### Scenario: 从面板进入设置
- **WHEN** 用户在学习助手面板中点击设置入口（底部导航或设置图标）
- **THEN** 中栏导航至 `LearningPreferencesView`

#### Scenario: 从草稿卡片跳转
- **WHEN** 用户在 IngestionView 草稿卡片中点击"去设置 →"
- **THEN** 中栏导航至 `LearningPreferencesView`
- **AND** 用户返回后仍停留在添加资料页，草稿状态保留

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

### Requirement: Bottom navigation responsiveness
The learning assistant bottom navigation SHALL switch selected tabs immediately and expose a reliable hit target for each visible item.

#### Scenario: Immediate tab selection feedback
- **WHEN** the backend is ready and the user clicks any bottom-navigation item
- **THEN** the selected tab state changes before any destination-specific data refresh is required to complete
- **AND** the clicked item renders selected visual feedback in the same UI update cycle

#### Scenario: Full item hit target
- **WHEN** the user clicks within the visible bounds of a bottom-navigation item, including padding around its icon or label
- **THEN** the system treats the click as activation of that item
- **AND** neighboring navigation items are not activated

#### Scenario: Destination load does not block navigation
- **WHEN** the destination tab starts an async refresh on entry
- **THEN** the assistant still displays the destination tab immediately
- **AND** loading feedback, if needed, is shown inside the destination content rather than delaying tab selection
