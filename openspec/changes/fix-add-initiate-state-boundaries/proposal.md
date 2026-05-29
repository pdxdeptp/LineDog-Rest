## Why

Add / Initiate 当前把路由澄清、草案澄清、非计划存储、激活成功等状态混在同一前端流里，用户可能遇到无草案卡死、未确认就显示已保存、激活后不知道是否成功等问题。

本变更只修正状态边界和终态反馈，保证用户明确知道“还在草案中”还是“已经创建主动任务”。

## What Changes

- 区分 route-level needs input 与 draft-level needs input。
- 对参考资料、稍后处理、一次性行动、material-only 附件增加明确确认与终态。
- 增加激活成功终态，展示计划已创建，并提供后续入口。
- 保持非 active 状态安静，不刷新 Today/Calendar/smart-mode surfaces。
- 保留 stale response guard，避免旧响应覆盖新会话或新版草案。

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `assistant-panel-ui`: 修正 Add / Initiate 状态分流、非计划确认、激活成功终态和 active surface 刷新边界。

## Impact

- Affected Swift files: `MalDaze/LearningAssistant/AssistantPanelView.swift`, `MalDaze/LearningAssistant/LearningAssistantViewModel.swift`.
- Possible API impact only if existing response fields cannot reliably distinguish route clarification from draft clarification.
- Affected tests: `MalDazeTests/LearningAssistantTests.swift`; backend study-intake contract tests only if response fields change.
