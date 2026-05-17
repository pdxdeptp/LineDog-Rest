## ADDED Requirements

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
