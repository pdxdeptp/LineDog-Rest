## MODIFIED Requirements

### Requirement: 学习助手连接状态
学习助手中栏 SHALL 区分后端启动中、服务不可用和后端就绪状态。

#### Scenario: 后端启动中
- **WHEN** `LearningAssistantViewModel.isConnecting=true`
- **THEN** 中栏显示进度指示和“后端启动中…”提示
- **AND** 不将启动等待描述为错误或离线

#### Scenario: 服务不可用
- **WHEN** HTTP 请求失败并设置 `isOffline=true`
- **THEN** 整个学习助手中栏显示“助手离线”或等价服务不可用状态
- **AND** 提供重试按钮
- **AND** 不显示旧首页内容、局部失败内容或底部导航

#### Scenario: 后端就绪
- **WHEN** `BackendProcessManager` 发出 `backendDidBecomeReady` 通知
- **THEN** ViewModel 结束 connecting 状态
- **AND** 拉取首页所需的今日简报和资料状态

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

## ADDED Requirements

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
- **THEN** 前端显示明确的“打开链接”动作
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
