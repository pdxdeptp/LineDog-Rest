# Hermes · X8 · schedule-range

> **依赖**：现有 `week-load` / `available_days` / `get_ordered_tasks` 纪律。

## 1. CLI

- [x] 1.1 `cmd_schedule_range`：`--from` / `--to` / `--month`；默认当月 + deadline 延伸
- [x] 1.2 每日 `tasks[]` + 正课/复习分桶 + `after_project_deadline`
- [x] 1.3 响应 `deadlines[]`、可选 `truncated`（跨度上限 ~93 天）
- [x] 1.4 `schedule.py` docstring + `SKILL.md` 一句

## 2. 单测

- [x] 2.1 有课日 / 休息日 / 空日
- [x] 2.2 超容量与 `week-load` 一致
- [x] 2.3 `after_project_deadline` 与 overflow 场景
- [x] 2.4 更新 `integration_smoke`
