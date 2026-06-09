## Why

新建学习项目的唯一入口是飞书/Hermes 对话（US-2~5），但 SKILL 仍要求「手工写 projects.json」，且 MalDaze 面板空状态指引模糊。需要正式 `create-project` CLI 并收紧对话工作流，且建项目只需 **一层确认**（任务表），不需 `plan --dry-run`。

## What Changes

### Hermes

- 新增 `schedule.py create-project --id --name --deadline [--source-url]`。
- SKILL §1：`确认 → create-project → plan`（禁止手改 JSON）。
- 区分预览规则：**建项目** 单层确认；**move / set-deadline** 仍保留 dry-run。
- 修正 SKILL/references 过时 spec 路径；对齐 `build-hermes-learning-assistant-v1` plan-generation。

### MalDaze

- 项目 Tab 空状态、Insert Sheet：指向「Hermes 对话发链接 / 帮我安排学习」。
- **不**添加面板建项目 UI。

## Capabilities

### New Capabilities

（无新 spec id）

### Modified Capabilities

- `hermes-learning-calendar`: MODIFIED — 增加 `create-project` CLI requirement（命名沿用现有 spec 仓）。
- `learning-desk-panel`: MODIFIED — 空状态文案；明确 US-2~5 不在面板创建。

## Impact

- Hermes: `schedule.py`, SKILL, tests
- MalDaze: 文案 only
- docs: `hermes.md`, `learning-desk-panel.md`, MANUAL_QA

## Affected Specs

- `hermes-learning-calendar`
- `learning-desk-panel`
