## ADDED Requirements

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
