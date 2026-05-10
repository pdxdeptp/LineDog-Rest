## ADDED Requirements

### Requirement: 学习偏好读取 API
系统 SHALL 提供 `GET /api/settings/learning-preferences` 端点，返回当前学习偏好设置。

#### Scenario: 读取偏好
- **WHEN** 客户端调用 `GET /api/settings/learning-preferences`
- **THEN** 系统返回 `{"daily_capacity_min": <int>}`（从 system_state 读取）
- **AND** 若 key 不存在，返回默认值 60

### Requirement: 学习偏好写入 API
系统 SHALL 提供 `PUT /api/settings/learning-preferences` 端点，允许更新学习偏好。

#### Scenario: 更新每日学习容量
- **WHEN** 客户端发送 `PUT /api/settings/learning-preferences`，携带 `{"daily_capacity_min": <int>}`
- **THEN** 系统将新值写入 `system_state`
- **AND** 返回 `{"daily_capacity_min": <int>, "updated": true}`

#### Scenario: 无效值
- **WHEN** `daily_capacity_min` 小于 1 或大于 1440（24 小时）
- **THEN** 系统返回 HTTP 422，附带验证错误说明

### Requirement: 全局学习偏好设置页
前端 SHALL 提供 `LearningPreferencesView`，允许用户查看和修改每日学习容量。

#### Scenario: 查看当前容量
- **WHEN** 用户打开学习偏好设置页
- **THEN** 页面显示当前 `daily_capacity_min` 值（从 API 读取）

#### Scenario: 修改每日学习容量
- **WHEN** 用户调整每日学习容量（Stepper 或文本输入，范围 15–480 分钟，步长 15）
- **THEN** 前端调用 `PUT /api/settings/learning-preferences` 保存新值
- **AND** 页面显示保存成功提示

#### Scenario: 后端不可用时
- **WHEN** 打开设置页时后端离线
- **THEN** 显示"无法加载设置"提示，不崩溃
