## ADDED Requirements

### Requirement: 三栏面板布局
MalDaze 现有面板 SHALL 从双栏扩展为三栏。中间新增栏专用于学习助手。现有左栏和右栏的内容和功能 SHALL 保持不变。

#### Scenario: 三栏渲染
- **WHEN** 用户点击桌宠打开面板
- **THEN** 面板渲染为左栏 / 中栏（学习助手）/ 右栏三个区域，各栏内容独立滚动

---

### Requirement: 中栏 — 今日任务视图
中栏 SHALL 默认展示当日任务列表，数据来源于 Morning Agent 生成的摘要（通过 `GET /api/today-briefing` 获取）。

#### Scenario: 今日任务展示
- **WHEN** 用户打开面板且当日已触发 Morning Agent
- **THEN** 中栏显示今日任务列表，每项包含：任务标题、所属资料名、预估时长、完成状态（待完成/已完成）

#### Scenario: 任务完成标记
- **WHEN** 用户点击某任务左侧的完成按钮
- **THEN** 前端调用 `POST /api/tasks/{id}/complete`，服务端写入 completed_at，前端即时更新该任务视觉状态（划线/勾选）

#### Scenario: 今日尚未触发 Morning Agent
- **WHEN** 用户开机后 LaunchAgent 尚未触发，或后端未启动
- **THEN** 中栏显示上一日任务数据或空状态提示，不阻塞面板打开

---

### Requirement: 中栏 — 资料进度视图
中栏 SHALL 提供资料进度概览，可通过 Tab 或滚动切换到任务视图。

#### Scenario: 进度展示
- **WHEN** 用户切换到资料进度视图
- **THEN** 列出所有 status='active' 的资料，每项显示：标题、进度条（completed_units / total_units）、预计完成日期

---

### Requirement: 中栏 — 对话输入框
中栏底部 SHALL 提供一个文本输入框，用于与 Conversational Planner 交互。

#### Scenario: 发送对话消息
- **WHEN** 用户在输入框输入文字并按 Enter 或点击发送
- **THEN** 前端调用 `POST /api/chat`，将消息发送至 Conversational Planner，等待响应后在输入框上方展示 Agent 的回复或变更提案

#### Scenario: 变更提案展示
- **WHEN** Agent 调用 present_proposal 生成变更提案
- **THEN** 中栏在对话气泡区域展示变更摘要（diff 格式），并提供 [确认] / [取消] 两个按钮；用户点击后结果通过 `POST /api/chat/confirm` 回传

---

### Requirement: Material Ingestion 入口
中栏 SHALL 提供一个"添加学习资料"入口（按钮或拖拽区域），用于触发 Ingestion Agent。

#### Scenario: 粘贴 URL 添加资料
- **WHEN** 用户在 Ingestion 输入框粘贴 URL 并指定 deadline（或保留默认），点击"分析"
- **THEN** 前端调用 `POST /api/ingest`，展示 loading 状态；Ingestion Agent 完成后返回草稿，前端展示草稿供用户审核

#### Scenario: Ingestion 草稿审核
- **WHEN** Ingestion Agent 返回草稿（含每日任务分配和总工时）
- **THEN** 中栏展示草稿（分周 / 分天列表），用户可点击 [确认加入计划] 或 [取消]；确认后前端调用 `POST /api/ingest/confirm`

---

### Requirement: Swift ↔ 后端 HTTP 通信
MalDaze Swift 层 SHALL 通过 HTTP 与本地 FastAPI 后端通信，后端默认监听 `http://127.0.0.1:8765`。

#### Scenario: 后端未启动时的优雅降级
- **WHEN** Swift 层发起 HTTP 请求但后端无响应
- **THEN** 中栏展示"助手离线"状态，不崩溃，其余面板功能（番茄钟、待办等）正常运行

#### Scenario: 请求超时处理
- **WHEN** HTTP 请求超过5秒未响应
- **THEN** Swift 层取消请求，中栏显示"请求超时，请稍后重试"
