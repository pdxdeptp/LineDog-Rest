## MODIFIED Requirements

### Requirement: Dashboard Panel dismissal

系统 SHALL 使用自定义逻辑关闭桌宠 Dashboard Panel。

#### Scenario: Toggle hides dashboard

- **WHEN** Dashboard Panel 已经打开且用户再次触发桌宠打开动作
- **THEN** 系统关闭或隐藏该 Dashboard Panel
- **AND** 系统 SHALL pause all registered Dashboard quiescent consumers before or as part of hide completion

#### Scenario: State preservation on hide

- **WHEN** 系统隐藏 Dashboard Panel
- **THEN** MalDaze retains in-panel UI state such as scroll position, selected tab, and local drafts
- **AND** MalDaze stops Dashboard-scoped periodic CPU work including live timeline ticks and file watchers started by visible panels
