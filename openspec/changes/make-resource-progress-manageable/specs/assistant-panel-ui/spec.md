## MODIFIED Requirements

### Requirement: 资料进度视图
资料进度 Tab SHALL 展示 active 资料的进度概览，并 SHALL 提供可直接执行或进入既有计划调整流程的资料管理动作。

#### Scenario: 拉取资料
- **WHEN** 用户进入资料进度 Tab
- **THEN** 前端调用 `/api/resources`

#### Scenario: 资料卡片
- **WHEN** resources 非空
- **THEN** 每项显示资料标题、进度条、completed_units/total_units、累计投入时间、deadline 和 status badge
- **AND** 每项提供资料管理动作入口

#### Scenario: 打开资料链接
- **WHEN** 某资料包含有效 `url`
- **THEN** 资料卡片显示打开资料动作
- **AND** 用户触发该动作时系统打开该 `url`

#### Scenario: 无资料链接
- **WHEN** 某资料没有有效 `url`
- **THEN** 资料卡片不显示可点击的打开资料动作或显示不可用状态
- **AND** 前端不伪造或猜测跳转 URL

#### Scenario: 按资料调整计划
- **WHEN** 用户在某资料卡片选择调整计划
- **THEN** 中栏切换到调整计划视图
- **AND** 对话输入框预填包含该资料标题的计划调整提示
- **AND** 用户可编辑提示后再发送

#### Scenario: 标记资料完成
- **WHEN** 用户在某资料卡片确认标记完成
- **THEN** 前端调用资料完成 API
- **AND** 成功后重新拉取首页 dashboard 和资料列表

#### Scenario: 移出当前计划
- **WHEN** 用户在某资料卡片确认移出当前计划
- **THEN** 前端调用资料归档 API
- **AND** 成功后重新拉取首页 dashboard 和资料列表

#### Scenario: 管理动作失败
- **WHEN** 资料完成或归档 API 调用失败
- **THEN** 资料进度视图显示明确失败反馈
- **AND** 不从本地列表中移除该资料

#### Scenario: 无资料
- **WHEN** resources 为空
- **THEN** 视图显示暂无资料记录
