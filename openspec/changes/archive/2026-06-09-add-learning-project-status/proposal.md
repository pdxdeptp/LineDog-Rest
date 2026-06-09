## Why

学习面板 X7 已提供项目 Tab 与截止日编辑，但用户改截止日的真实诉求是：**新截止日确定后，剩余未完成课程应自动塞进可用学习日**，而不是只改元数据、任务仍落在旧日期上。

本变更在 `set-deadline` 上扩展 **US-10 v2**：更新 `deadline` 后，对该项目 **未完成** 任务做一次 **顺序重排（repack）**，算法与 `plan` 的顺序填充一致；**已完成** 任务不动。

总目录：[ROADMAP.md](../../../docs/integrations/ROADMAP.md) X7 · 母本：[learning-desk-panel.md](../../../docs/integrations/features/learning-desk-panel.md) US-10 / US-12

## What Changes

### Hermes

- 扩展 `schedule.py set-deadline --project-id <id> --deadline YYYY-MM-DD`：
  - 更新 active 项目 `deadline`。
  - **默认**对该项目所有 **未完成** 任务（`pending` / `failed`）按 JSON 列表顺序，从 **今天** 起在 `[today, new_deadline]` 的可用非休息日内 **顺序填充**（正课用 `daily_capacity_minutes`，复习用 `review_budget_minutes`，同 `plan` / `validate` 纪律）。
  - **已完成** 任务：`scheduled_date` 与历史不变。
  - 装不下的任务进入 `overflow_tasks[]`；`deadline_exceeded` / `overflow_count` 反映是否仍有课落在截止日后或无法排入。
  - 可选 `set-deadline --dry-run`：预览 `changes[]`，不写盘（供面板确认）。
  - 可选 `--no-repack`：仅改 deadline、不移动任务（调试/兼容；**面板不用**）。

### MalDaze

- 项目 Tab 截止日 sheet 确认文案改为说明 **会重排未完成课程**。
- 确认前可选展示 `dry-run` 的 `changes[]` 摘要（条数 + 首几条）。
- 成功后刷新 **今日 + 周负荷 + 项目 status**；`overflow` 用 `actionNotice` 提示。

## Capabilities

### Modified Capabilities

- `learning-desk-panel`: MODIFIED — US-10 截止日编辑触发 repack 预览/确认与刷新链。
- `hermes-learning-calendar`: MODIFIED — `set-deadline` 可移动未完成任务的 `scheduled_date`（JSON only）。

## Impact

- **Hermes**：`cmd_set_deadline` 重写/扩展 + repack  helper + 单测更新。
- **MalDaze**：确认 sheet 文案、可选预览、`HermesSetDeadlineResponse` 扩展字段、刷新 week。
- **破坏性**：现有「只改 deadline 不移动任务」行为改为 **默认 repack**（`--no-repack` 保留旧语义）。

## Affected Specs

- `learning-desk-panel`（delta MODIFIED）
- `hermes-learning-calendar`（delta MODIFIED）
