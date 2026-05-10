# ingestion-progress-sse Specification

## Purpose

学习资料导入在后台异步执行；客户端通过 Server-Sent Events 接收各分析阶段进度与终态（草稿就绪或错误），无需阻塞等待同步 HTTP 响应。

## Requirements

### Requirement: 分析启动立即返回
系统 SHALL 在用户提交 URL 后立即返回 thread_id，不等待分析完成。

#### Scenario: 启动请求响应
- **WHEN** 客户端发送 `POST /api/ingest/start`，携带 `url`、`deadline`、`speed_factor`
- **THEN** 系统立即返回 `{"thread_id": "<uuid>"}` （HTTP 200）
- **AND** 后台开始异步运行分析图

### Requirement: SSE 实时进度推送
系统 SHALL 通过 `GET /api/ingest/progress/{thread_id}` 以 SSE 格式推送四个阶段事件。

#### Scenario: 正常进度序列
- **WHEN** 客户端订阅 SSE 端点
- **THEN** 系统依次推送如下事件（每个节点完成后立即推送）：
  - `{"phase": "fetch_structure", "label": "正在读取章节结构…", "done": false}`
  - `{"phase": "estimate_time",   "label": "正在估算学习时长…", "done": false}`
  - `{"phase": "check_capacity",  "label": "正在生成排期方案…", "done": false}`
  - `{"phase": "draft_ready",     "label": "草稿已就绪",        "done": true, "draft": {...}}`
- **AND** 推送 `draft_ready` 后连接关闭

#### Scenario: 分析失败
- **WHEN** 分析过程中任意节点抛出异常（如 URL 无法解析或无法抓取资料）
- **THEN** 系统推送 `{"phase": "error", "label": "<错误描述>", "done": true, "error": "<类型>"}`
- **AND** 连接关闭
- **AND** 不写入数据库

#### Scenario: thread_id 不存在
- **WHEN** 客户端请求的 thread_id 不在服务进度表中
- **THEN** 系统返回 HTTP 404

#### Scenario: SSE 连接中断
- **WHEN** 客户端在收到 `draft_ready` 前断开连接
- **THEN** 后台分析任务继续运行至完成
- **AND** 进度事件写入内存队列（直到超时 300 秒后清理）
- **AND** 客户端重连同一 thread_id 后可读取累积的事件

#### Scenario: 客户端检测到流关闭但未收到终态事件
- **WHEN** Swift 侧 `URLSession.bytes` 流提前结束（非 `draft_ready` / `error` 触发）
- **THEN** UI 显示"连接中断，请重新提交链接分析"提示
- **AND** `isIngesting` 设为 false
- **AND** URL TextField 内容保持不变
- **AND** 不自动重连，不自动重试

### Requirement: Swift 侧 SSE 解析
Swift 客户端 SHALL 用 `URLSession.bytes(for:)` 逐行读取 SSE，解析 `data:` 前缀行。

#### Scenario: 阶段事件更新 UI
- **WHEN** 客户端收到非终态事件（`done: false`）
- **THEN** UI 更新当前阶段标签，显示对应 `label`

#### Scenario: draft_ready 更新草稿
- **WHEN** 客户端收到 `done: true` 且 `phase: "draft_ready"`
- **THEN** UI 退出进度显示，展示草稿卡片
- **AND** `ingestionDraft` 赋值

#### Scenario: error 事件
- **WHEN** 客户端收到 `phase: "error"`
- **THEN** UI 显示错误信息，允许用户修改 URL 重试
- **AND** `isIngesting` 设为 false
