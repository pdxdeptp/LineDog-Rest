# weekly-review-agent Specification

## Purpose

Weekly Review Agent 负责聚合一周学习数据、判断是否建议减载、生成下周计划草稿，并在用户确认后更新现有任务、plan.md 和事件记录。

## Requirements

### Requirement: 周日定时触发
系统 SHALL 通过 APScheduler 在每周日 20:00 触发 Weekly Review。

#### Scenario: 定时触发
- **WHEN** 后端进程在周日 20:00 正常运行
- **THEN** APScheduler 启动 Weekly Review 流程

#### Scenario: 离线补偿
- **WHEN** 周日 20:00 后端未运行
- **THEN** 下次 Morning Agent 启动时通过 `weekly_review_done` 事件检测缺失复盘
- **AND** 自动补触发 Weekly Review 子流程

### Requirement: 周数据聚合
系统 SHALL 聚合本周完成率、任务重排次数、资料风险和速度系数调整。

#### Scenario: 任务完成率
- **WHEN** Weekly Review 聚合数据
- **THEN** 系统查询本周任务总数与 completed_at 非空数量
- **AND** 计算 completion_rate

#### Scenario: deadline 风险
- **WHEN** 存在 active 资料且包含 deadline
- **THEN** 系统估算剩余工时与剩余 capacity
- **AND** 标记可能超期的资料

#### Scenario: 速度系数调整摘要
- **WHEN** 本周存在 `speed_factor_changed` 事件
- **THEN** 系统将相关调整纳入 week_stats

### Requirement: 减载建议
系统 SHALL 基于完成率和重排次数判断是否建议减载。

#### Scenario: 建议减载
- **WHEN** 本周 completion_rate < 0.6 或 total_reschedule_count > 5
- **THEN** Weekly Review 标记 `suggest_reduced_load=true`

#### Scenario: 不建议减载
- **WHEN** 本周完成率和重排次数处于正常范围
- **THEN** Weekly Review 不建议减载

### Requirement: 下周草稿
系统 SHALL 使用 LLM 基于 week_stats、resource_risks 和 plan.md 生成下周草稿。

#### Scenario: 草稿结构
- **WHEN** 草稿生成成功
- **THEN** draft 包含 summary 和 task_updates

#### Scenario: 草稿解析失败
- **WHEN** LLM 输出无法解析为 JSON
- **THEN** 系统使用兜底草稿

### Requirement: 人工确认
系统 SHALL 支持用户确认、取消或带编辑确认 Weekly Review 草稿。

#### Scenario: 手动触发
- **WHEN** 用户调用 `POST /api/weekly-review/trigger`
- **THEN** 系统返回 thread_id 和当前 graph 状态

#### Scenario: 获取草稿
- **WHEN** 用户调用 `GET /api/weekly-review/draft/{thread_id}`
- **THEN** 系统返回 draft、suggest_reduced_load 和状态

#### Scenario: 用户确认
- **WHEN** 用户调用 `POST /api/weekly-review/confirm` 且 confirmed=true
- **THEN** 系统更新 task_updates 指向的现有任务
- **AND** 写入 `weekly_review_done` 事件

#### Scenario: 用户取消
- **WHEN** 用户调用 `POST /api/weekly-review/confirm` 且 confirmed=false
- **THEN** 系统返回 cancelled
- **AND** 不应用草稿中的任务更新

### Requirement: 任务更新范围
Weekly Review SHALL 只更新现有任务，不创建新任务。

#### Scenario: 更新已有任务
- **WHEN** task_updates 包含 task_id
- **THEN** 系统可更新该任务 scheduled_date、priority 或 status

#### Scenario: 不插入任务
- **WHEN** Weekly Review 应用草稿
- **THEN** 系统不插入新的 tasks 行
