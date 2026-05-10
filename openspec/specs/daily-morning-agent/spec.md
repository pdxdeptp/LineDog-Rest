# daily-morning-agent Specification

## Purpose

Morning Agent 负责在每天为学习助手生成今日简报、重排昨日未完成任务、补触发缺失的周复盘，并基于近期表现调整资料速度系数。

## Requirements

### Requirement: 今日简报幂等
系统 SHALL 对同一日历日的 Morning Agent 结果进行缓存，避免重复重排和重复 LLM 调用。

#### Scenario: 今日已有缓存
- **WHEN** `system_state` 中存在 `briefing_YYYY-MM-DD`
- **THEN** `run_morning_agent()` 返回缓存内容
- **AND** 不重新执行重排流程

#### Scenario: 今日无缓存
- **WHEN** 今日 briefing 缓存不存在
- **THEN** Morning Agent 执行检查周复盘、重排任务、校准速度系数、生成简报的流程

### Requirement: Weekly Review 补触发检查
系统 SHALL 在 Morning Agent 开始时检查上一个周日是否已有 `weekly_review_done` 事件。

#### Scenario: 缺少周复盘事件
- **WHEN** 上一个周日不存在 `weekly_review_done` 事件
- **THEN** Morning Agent 先运行 Weekly Review 子流程
- **AND** 然后继续生成今日简报

#### Scenario: 周复盘已完成
- **WHEN** 上一个周日存在 `weekly_review_done` 事件
- **THEN** Morning Agent 跳过补触发

### Requirement: 昨日未完成任务重排
系统 SHALL 查询昨日未完成任务，并将其移动到今天或后续最近可容纳日期。

#### Scenario: 今日容量足够
- **WHEN** 今日剩余 capacity 足以容纳某个昨日未完成任务
- **THEN** 系统将该任务 `scheduled_date` 更新为今天
- **AND** 增加 `reschedule_count`

#### Scenario: 今日容量不足
- **WHEN** 今日剩余 capacity 不足以容纳某个昨日未完成任务
- **THEN** 系统向后查找最近可容纳该任务的日期
- **AND** 将任务移动到该日期

#### Scenario: 重排事件
- **WHEN** 系统重排任意任务
- **THEN** 系统写入 `task_rescheduled` 事件，记录 from_date 与 to_date

### Requirement: 速度系数校准
系统 SHALL 基于近期完成率和重排率调整 active 资料的 `speed_factor`。

#### Scenario: 数据不足
- **WHEN** 某资料近 14 天任务数少于 5
- **THEN** 系统不调整该资料 speed_factor

#### Scenario: 实际偏慢
- **WHEN** 某资料 reschedule_rate > 0.4 且当前 speed_factor > 0.5
- **THEN** 系统将 speed_factor 乘以 0.9 并保留两位小数
- **AND** 写入 `speed_factor_changed` 事件

#### Scenario: 实际偏快
- **WHEN** 某资料 completion_rate > 0.9、reschedule_rate < 0.1 且当前 speed_factor < 2.0
- **THEN** 系统将 speed_factor 乘以 1.05 并保留两位小数
- **AND** 写入 `speed_factor_changed` 事件

### Requirement: 今日简报内容
系统 SHALL 生成包含今日任务、总预估分钟数、进度摘要、负荷模式和任务学习链接的简报。

#### Scenario: 简报任务列表
- **WHEN** Morning Agent 查询今日任务
- **THEN** 每个任务包含 id、title、target_minutes、completed_at、resource_title、priority
- **AND** 每个任务包含 `resource_url` 字段，值来自关联 resource 的 url，若无关联资料或资料无 URL 则为 null
- **AND** 每个任务包含 `unit_url` 字段，若系统有单元级 URL 则填充，否则为 null

#### Scenario: 资源级链接兜底
- **WHEN** 今日任务关联 unit 但该 unit 没有单元级 URL
- **THEN** 简报任务项仍返回关联 resource 的 `resource_url`

#### Scenario: 无可用学习链接
- **WHEN** 今日任务没有关联 resource 或关联 resource 没有 url
- **THEN** 简报任务项返回 `resource_url=null`
- **AND** 返回 `unit_url=null`

#### Scenario: highlights 生成
- **WHEN** LLM 可用
- **THEN** 系统生成一句 15-30 字的今日状态摘要

#### Scenario: highlights 兜底
- **WHEN** LLM 调用失败
- **THEN** 系统使用基于任务数量和总分钟数的兜底摘要

#### Scenario: 简报缓存
- **WHEN** 今日简报生成完成
- **THEN** 系统写入 `morning_briefing_generated` 事件
- **AND** 将简报 JSON 写入 `system_state.briefing_YYYY-MM-DD`

### Requirement: 应用拥有的后端进程随应用退出收束
系统 SHALL 在 MalDaze 应用退出时终止由当前 MalDaze 进程显式 spawn 的学习助手后端子进程，并 SHALL NOT 通过端口监听进程扫描来推断后端所有权。

#### Scenario: 当前会话拥有后端子进程
- **WHEN** MalDaze 本次启动时 spawn 了学习助手后端
- **AND** 用户通过 Cmd+Q 或应用退出流程终止 MalDaze
- **THEN** 系统终止该后端子进程
- **AND** `127.0.0.1:8765` 不再由该子进程监听

#### Scenario: 后端检测到父进程消失
- **WHEN** 学习助手后端由 MalDaze spawn 并收到预期父进程身份
- **AND** 后端运行期间发现当前父进程不再是该 MalDaze 进程
- **THEN** 后端 SHALL 主动优雅退出

#### Scenario: 端口由外部服务占用
- **WHEN** MalDaze 启动时发现 `127.0.0.1:8765` 已被占用
- **THEN** 系统 SHALL 将该端口仅视为可连接的外部后端服务
- **AND** MalDaze 退出时 SHALL NOT 终止该监听进程

#### Scenario: 端口探测不授予终止权限
- **WHEN** MalDaze 退出时存在监听 `127.0.0.1:8765` 的进程
- **AND** 该进程不是当前 MalDaze 进程显式 spawn 的后端子进程
- **THEN** 系统 SHALL NOT 因端口号、命令行或工作目录匹配而终止该进程
