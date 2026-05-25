# progress-feedback Specification

## Purpose

学习助手通过任务完成、资料进度、每日摘要、速度系数调整和周复盘数据向用户反馈学习进展。当前规格只记录已实现的反馈能力，不包含尚未实现的 Stats Tab、里程碑通知或成就系统。
## Requirements
### Requirement: 任务完成即时进度更新
系统 SHALL 在用户完成任务后同步更新相关任务、学习单元和资料进度。

#### Scenario: sequential 资料任务完成
- **WHEN** 用户完成一个关联 unit 的任务
- **THEN** 系统更新 task.completed_at
- **AND** 更新 unit.status、unit.completed_at、unit.actual_minutes
- **AND** 将 resource.completed_units 加 1
- **AND** 将 resource.actual_minutes_total 增加任务实际分钟数或目标分钟数

#### Scenario: 任务完成后前端刷新
- **WHEN** 前端完成 `POST /api/tasks/{id}/complete`
- **THEN** `LearningAssistantViewModel` 重新拉取今日简报

### Requirement: 资料进度概览
系统 SHALL 在学习助手中栏展示 active 资料的当前进度。

#### Scenario: 进度条
- **WHEN** 资料 total_units > 0
- **THEN** 前端以 completed_units / total_units 计算进度条

#### Scenario: 累计投入
- **WHEN** 资料包含 actual_minutes_total
- **THEN** 前端以小时和分钟显示累计投入时间

#### Scenario: 资料状态
- **WHEN** 资料 status 为 active、completed 或 overdue
- **THEN** 前端显示对应状态徽标

### Requirement: Morning Briefing 进度摘要
系统 SHALL 在每日简报中生成一句进度摘要。

#### Scenario: LLM 摘要
- **WHEN** Morning Agent 可调用 LLM
- **THEN** highlights 反映今日任务总量、负荷模式、资料进度或速度系数调整

#### Scenario: 摘要兜底
- **WHEN** LLM 摘要生成失败
- **THEN** highlights 使用任务数量和总分钟数生成兜底文本

### Requirement: 速度系数调整反馈
系统 SHALL 在检测到学习速度偏差时调整资料 speed_factor 并记录事件。

#### Scenario: 速度调整事件
- **WHEN** Morning Agent 调整某资料 speed_factor
- **THEN** 系统写入 `speed_factor_changed` 事件，包含 resource_id、old_factor、new_factor

#### Scenario: 周复盘读取调整
- **WHEN** Weekly Review 聚合本周数据
- **THEN** 系统读取本周 `speed_factor_changed` 事件并放入 week_stats

### Requirement: 资料管理即时反馈
系统 SHALL 在用户管理资料后立即刷新学习助手中的资料进度和今日状态。

#### Scenario: 标记完成后的刷新
- **WHEN** 前端完成资料标记完成请求
- **THEN** `LearningAssistantViewModel` 重新拉取今日简报和资料列表
- **AND** 完成后的资料不再作为 active 资料显示

#### Scenario: 移出计划后的刷新
- **WHEN** 前端完成资料归档请求
- **THEN** `LearningAssistantViewModel` 重新拉取今日简报和资料列表
- **AND** 被移出的资料不再作为 active 资料显示

#### Scenario: 管理错误反馈
- **WHEN** 资料管理请求失败
- **THEN** 前端保留现有资料进度数据
- **AND** 前端向用户显示该管理动作失败
