## Why

学习面板「今日」Tab 已能列出 pending 并完成/推迟，但主 spec / feature 文档仍缺的 **双预算（正课+复习）、完成驱动反馈、滚入债可见性、实际时长采集、多项目可读性** 仍未落地。用户并行 LC + Agent 等多项目时，今日视图像冷清单——勾完即消失、超额只见正课桶、滚入任务混在列表里难扫。

本 change 强化 **执行台（execution cockpit）** 本体，不扩 Tab、不引入智能模式。

依据：`openspec/specs/learning-desk-panel/spec.md`（delta 见本 change）· [learning-desk-panel.md](../../../docs/integrations/features/learning-desk-panel.md) · 前置已归档 `add-learning-desk-panel` 系列

## What Changes

### Hermes `schedule.py today`（小扩展）

- 响应增加 **今日已完成统计**（从 `daily_log.json` 汇总）：正课/复习各 `done` + `total`（total = 今日仍 pending + 今日已 completed）。
- 无新子命令；`pending[]` 形状不变。

### MalDaze 今日 Tab

1. **双预算顶栏**：正课 `Xh/Yh` + 复习 `Xm/Zm`；任一桶超额标红。
2. **今日完成进度**：正课/复习 `done/total` + 细进度条。
3. **滚入置顶区**：`auto_roll_days >= 3` 的任务单独列出，保留完成/推迟。
4. **完成可选实际时长**：完成后轻量 sheet，默认计划时长，提交 `complete --actual-minutes`。
5. **按项目分组切换**：扁平 ↔ 按 `project_name` 折叠。

### 文档

- `learning-desk-panel.md` 今日章节；`MANUAL_QA` 增 M-L12-core。

## Capabilities

### New Capabilities

（无独立新 spec id）

### Modified Capabilities

- `learning-desk-panel`: MODIFIED — 今日双预算、完成进度、滚入区、实际时长、项目分组。
- `hermes-learning-calendar`: MODIFIED — `today` JSON 增加今日完成进度字段。

## Impact

- **Hermes**：`cmd_today` + 单测。
- **MalDaze**：`LearningDeskPanelView`、`LearningTaskRow`、ViewModel/Models；可选新小组件。
- **非目标**：明日预览、行动卡、源链接、编号快完成（见 `extend-learning-today-navigation`）；智能模式；Swift 本地排期。
- **依赖**：在 `extend-learning-today-navigation` 之前实施（导航 change 依赖本 change 顶栏/分组基础）。

## Affected Specs

- `learning-desk-panel`
- `hermes-learning-calendar`
