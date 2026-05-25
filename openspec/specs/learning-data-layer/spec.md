# learning-data-layer Specification

## Purpose

学习助手使用本地 SQLite 数据库与 `plan.md` 文件保存学习资料、学习单元、每日任务、计划版本、事件流和运行时状态。该规格描述当前已实现的数据层行为，作为后续学习助手重修的 baseline。
## Requirements
### Requirement: SQLite 数据库初始化
系统 SHALL 使用单个 SQLite 文件存储学习助手运营数据，并在后端首次启动时自动创建所需表和索引。

#### Scenario: 首次启动初始化
- **WHEN** 后端启动且数据库文件不存在
- **THEN** 系统创建 `resources`、`units`、`tasks`、`plan_versions`、`events`、`system_state` 表
- **AND** 系统写入默认 `system_state`：`load_mode=normal`、`daily_capacity_min=300`、`reduced_capacity_min=60`、`user_speed_factor=1.0`

### Requirement: 学习资料记录
系统 SHALL 使用 `resources` 表记录学习资料元数据、进度、估算工时、实际投入和截止日期。

#### Scenario: 资料写入
- **WHEN** 用户确认一个导入草稿
- **THEN** 系统写入一条 `resources` 记录，包含 title、type、tracking_mode、url、total_units、estimated_hours、deadline、speed_factor
- **AND** 新资料默认 `status='active'`

#### Scenario: 资料完成
- **WHEN** 某资料的 `completed_units >= total_units`
- **THEN** 系统将该资料 `status` 更新为 `completed`
- **AND** 系统写入 `resource_completed` 事件

### Requirement: 学习单元记录
系统 SHALL 使用 `units` 表记录 sequential 类型资料的章节、视频或模块。

#### Scenario: 单元按资料排序
- **WHEN** 系统查询某资料的学习单元
- **THEN** 单元可通过 `resource_id` 与 `order_index` 按原始学习顺序排列

#### Scenario: 单元完成同步
- **WHEN** 用户完成一个关联 `unit_id` 的任务
- **THEN** 系统将对应 unit 更新为 `status='completed'`
- **AND** 写入 `completed_at` 和 `actual_minutes`

### Requirement: 每日任务记录
系统 SHALL 使用 `tasks` 表记录具体排期任务。

#### Scenario: 任务排期
- **WHEN** 系统生成学习计划
- **THEN** 每个任务包含 title、task_kind、target_minutes 或 target_count、scheduled_date、resource_id，以及可选 unit_id

#### Scenario: 任务完成
- **WHEN** 用户在前端标记任务完成
- **THEN** 系统写入 `completed_at`
- **AND** 若前端提供实际耗时，系统写入 `actual_minutes`
- **AND** 系统写入 `task_completed` 事件

#### Scenario: 任务重排
- **WHEN** 系统将任务从日期 A 移动到日期 B
- **THEN** 系统更新 `scheduled_date=B`
- **AND** 将 `reschedule_count` 加 1
- **AND** 写入 `task_rescheduled` 事件

### Requirement: plan.md 版本快照
系统 SHALL 将 `plan.md` 作为长期战略计划文本，并在写入后保存版本快照。

#### Scenario: 读取 plan.md
- **WHEN** Agent 调用 `get_current_plan`
- **THEN** 系统返回 `PLAN_MD_PATH` 指向文件的完整文本内容

#### Scenario: 写入 plan.md
- **WHEN** Agent 调用 `rewrite_plan`
- **THEN** 系统写入新的 `plan.md` 内容
- **AND** 将完整内容保存到 `plan_versions`

### Requirement: 不可变事件流
系统 SHALL 使用 `events` 表记录重要系统事件。

#### Scenario: 事件写入
- **WHEN** 资料添加、任务完成、任务重排、计划更新、资料完成、速度系数调整、晨报生成或周复盘完成
- **THEN** 系统插入一条事件记录
- **AND** payload 使用 JSON 字符串保存事件上下文

### Requirement: 全局运行时状态
系统 SHALL 使用 `system_state` 表保存全局配置和缓存状态。

#### Scenario: capacity 读取
- **WHEN** Morning Agent 或 Ingestion Agent 需要计算排期容量
- **THEN** 系统从 `system_state` 读取 `daily_capacity_min` 或 `reduced_capacity_min`

#### Scenario: 今日晨报缓存
- **WHEN** Morning Agent 生成今日晨报
- **THEN** 系统将结果写入 `system_state` 的 `briefing_YYYY-MM-DD` 键

### Requirement: 用户驱动的资料状态管理
系统 SHALL 支持用户显式管理学习资料状态，且不得硬删除资料历史记录。

#### Scenario: 手动标记资料完成
- **WHEN** 用户将某 active 资料标记为完成
- **THEN** 系统将该资料 `status` 更新为 `completed`
- **AND** 系统将该资料 `completed_units` 至少更新到 `total_units`
- **AND** 系统将该资料尚未完成的 units 更新为 `status='completed'`
- **AND** 系统写入 `resource_completed` 事件，payload 包含 `resource_id` 和用户动作来源

#### Scenario: 将资料移出当前计划
- **WHEN** 用户将某 active 资料移出当前计划
- **THEN** 系统将该资料 `status` 更新为 `archived`
- **AND** 系统移除该资料今天及未来尚未完成的排期任务
- **AND** 系统保留该资料、units、已完成任务和历史 events
- **AND** 系统写入 `resource_archived` 事件，payload 包含 `resource_id`

#### Scenario: 非 active 资料重复管理
- **WHEN** 用户对不存在或不再 active 的资料执行完成或归档操作
- **THEN** 系统返回失败响应
- **AND** 系统不写入新的状态变更事件

### Requirement: 资料管理后的活跃资料查询
系统 SHALL 将完成或归档后的资料排除出 active 资料查询结果。

#### Scenario: 查询 active 资料
- **WHEN** 某资料状态为 `completed` 或 `archived`
- **THEN** `/api/resources` 不返回该资料
- **AND** 今天及未来的简报不继续展示该资料被移出计划后遗留的未完成任务
