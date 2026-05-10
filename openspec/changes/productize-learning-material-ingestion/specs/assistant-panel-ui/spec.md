## ADDED Requirements

### Requirement: 学习偏好入口
学习助手中栏 SHALL 提供进入学习偏好设置页的入口。

#### Scenario: 从面板进入设置
- **WHEN** 用户在学习助手面板中点击设置入口（底部导航或设置图标）
- **THEN** 中栏导航至 `LearningPreferencesView`

#### Scenario: 从草稿卡片跳转
- **WHEN** 用户在 IngestionView 草稿卡片中点击"去设置 →"
- **THEN** 中栏导航至 `LearningPreferencesView`
- **AND** 用户返回后仍停留在添加资料页，草稿状态保留
