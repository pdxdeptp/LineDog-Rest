## MODIFIED Requirements

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
