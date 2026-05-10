# conversational-planner Specification

## Purpose

Conversational Planner 通过本地 FastAPI API 接收用户自然语言，使用固定 LangGraph 拓扑读取计划数据、生成文字回复或计划变更提案，并在用户确认后执行写入。

## Requirements

### Requirement: 固定 Graph 拓扑
系统 SHALL 使用固定拓扑处理对话规划请求：Plan → Gather → Propose → Respond 或 Human Review → Execute。

#### Scenario: 无需变更的查询
- **WHEN** 用户询问当前计划或今日任务
- **THEN** Graph 生成文字回复
- **AND** API 返回 `response`，不返回 proposal

#### Scenario: 需要确认的变更
- **WHEN** 用户请求修改任务或降低负荷
- **THEN** Graph 生成 proposal
- **AND** 在 `human_review` 前暂停，等待用户确认或取消

### Requirement: Plan 节点意图识别
系统 SHALL 使用 LLM 识别用户意图并决定需要调用哪些读工具。

#### Scenario: 任务变更请求
- **WHEN** 用户要求修改某天任务
- **THEN** Plan 节点必须选择 `get_tasks_by_date`
- **AND** 指定目标日期参数

#### Scenario: 减载表达
- **WHEN** 用户输入表达疲劳、没状态、想摆或希望减少任务的语义
- **THEN** intent 包含 `load_reduction`

### Requirement: Gather 节点读工具
系统 SHALL 在 Gather 阶段调用只读工具收集计划上下文。

#### Scenario: 支持的读工具
- **WHEN** Plan 节点请求工具
- **THEN** Gather 可调用 `get_tasks_by_date`、`get_current_plan`、`get_task_stats`、`get_resource_progress`、`check_capacity`

#### Scenario: 并行读取
- **WHEN** 多个读工具被请求
- **THEN** 系统并行执行这些读取并合并到 gathered_data

### Requirement: Propose 节点输出
系统 SHALL 将 LLM 输出规范化为 proposal。

#### Scenario: proposal 字段
- **WHEN** Propose 节点生成结果
- **THEN** proposal 包含 description、changes、affects_deadline、summary_for_user

#### Scenario: 无变更回复
- **WHEN** proposal.changes 为空
- **THEN** Graph 路由到 respond
- **AND** API 返回文字 response

#### Scenario: 有变更提案
- **WHEN** proposal.changes 非空
- **THEN** Graph 路由到 human_review
- **AND** API 返回 proposal 与 thread_id

### Requirement: 用户确认门禁
系统 SHALL 只在用户确认后执行写操作。

#### Scenario: 用户确认
- **WHEN** 用户调用 `/api/chat/confirm` 且 `confirmed=true`
- **THEN** 系统恢复 Graph 并执行 pending changes
- **AND** 返回 `status='applied'`

#### Scenario: 用户取消
- **WHEN** 用户调用 `/api/chat/confirm` 且 `confirmed=false`
- **THEN** 系统恢复 Graph 但不修改计划
- **AND** 返回 `status='cancelled'`

### Requirement: 支持的写操作
系统 SHALL 支持对任务日期和优先级的受控修改。

#### Scenario: reschedule 操作
- **WHEN** pending change 为 `action='reschedule'`
- **THEN** 系统调用 `reschedule_task` 更新 scheduled_date

#### Scenario: update 操作
- **WHEN** pending change 为 `action='update'`
- **THEN** 系统可更新任务 priority 或 scheduled_date

#### Scenario: 计划更新事件
- **WHEN** Execute 阶段完成
- **THEN** 系统写入 `plan_updated` 事件，记录 applied 数量和 intent

### Requirement: 对话线程
系统 SHALL 使用 thread_id 区分对话会话。

#### Scenario: 新对话
- **WHEN** `/api/chat` 请求未提供 thread_id
- **THEN** 系统生成新的 thread_id

#### Scenario: 继续对话
- **WHEN** `/api/chat` 请求提供已有 thread_id
- **THEN** 系统在同一 LangGraph checkpoint 线程中继续处理
