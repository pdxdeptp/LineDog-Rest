# 学习任务（已移除飞书日历投影）

> **2026-06-08+**：学习域不再同步飞书日历。本文档保留为历史索引；现行说明见 [learning-desk-panel.md](./learning-desk-panel.md)。

Hub：[../hermes.md](../hermes.md) · OpenSpec：`openspec/specs/hermes-learning-calendar/spec.md` · change：`remove-feishu-learning-calendar`

## 现行职责

| | Hermes | MalDaze |
|---|:------:|:-------:|
| 学习任务 SSOT（`projects.json`） | ✅ | ❌ |
| 新建项目（`create-project` + `plan`） | ✅ 对话入口 | ❌ 无建项目 UI |
| plan / complete / move / remove / set-deadline | ✅ | 面板经 CLI |
| 飞书对话完成交互 | ✅ | ❌ |

## SSOT 与完成

- **SSOT** = `~/.hermes/data/learning-assistant/projects.json`
- **完成**：飞书/Hermes 对话 `schedule.py complete`，或 MalDaze 学习面板同命令
- **不**把学习任务迁入苹果提醒事项

## 已移除（勿再排查）

- `feishu_enabled` / `feishu_calendar_id` / `calendar_on_complete`
- `calendar-sync` 子命令、`feishu_event_id` 写入、`calendar_errors[]`
- `references/calendar-setup.md`、`calendar-orphan-cleanup.md`

遗留 `feishu_event_id` 字段在旧 `projects.json` 中可忽略；新任务不再写入。
