## Why

MalDaze 学习面板与 Hermes `schedule.py` 已以 `projects.json` 为唯一排期 SSOT；飞书日历投影造成双份真相、同步失败与维护成本，且用户已决定彻底放弃学习场景的飞书日历。

## What Changes

### Hermes

- **BREAKING** 移除 `schedule.py` 全部飞书日历集成：`calendar-sync` 子命令、Feishu API、`feishu_event_id` 读写、`calendar_errors[]`、`--no-calendar` 标志。
- 从 `profile.json` 移除 `feishu_enabled`、`feishu_calendar_id`、`calendar_on_complete`。
- 从 task schema 剥离 `feishu_event_id`（迁移忽略遗留字段）。
- 删除/更新 `test_schedule_calendar.py`、integration smoke 日历断言。
- 更新 `learning-assistant` SKILL：删除日历章节与 `calendar-setup.md`、`calendar-orphan-cleanup.md`。
- 同步 `~/.hermes/openspec/changes/build-hermes-learning-assistant-v1/` 口径（去掉 `learning-calendar-sync` 能力描述）。

### MalDaze

- 移除 CLI 响应中的 `calendar_errors` 解码与 UI 提示。
- 更新 `docs/integrations` 架构图与 ROADMAP（学习不再写飞书日历）。
- 作废 `fix-learning-rollover-calendar` change（不再需要 rollover 日历 patch）。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `hermes-learning-calendar`: **REMOVED** 全部飞书投影 requirement；保留 JSON SSOT、move dry-run、无 Apple Reminders 迁移；重述 Purpose 为纯 JSON 排期。
- `learning-desk-panel`: MODIFIED — 移除 calendar 错误提示；明确不依赖任何外部日历。

## Impact

- **Hermes**: `schedule.py`、profile、projects 数据、tests、skill、integration_smoke。
- **MalDaze**: `HermesScheduleModels`、`LearningDeskPanelViewModel`、docs。
- **不影响**: `integration-feishu-qa`（桌宠 QA 铃铛）、飞书 **对话** 入口。

## Affected Specs

- `hermes-learning-calendar`
- `learning-desk-panel`
