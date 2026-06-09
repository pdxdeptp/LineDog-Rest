## Context

学习助手 v1 将飞书日历作为可选投影；MalDaze 面板与日程 Tab 已只读 `projects.json`（经 CLI）。继续保留日历代码无用户价值且与 SSOT 冲突。

## Goals / Non-Goals

**Goals**

- `schedule.py` 所有写路径只改 JSON + `daily_log`。
- CLI JSON 输出不再含 `calendar_errors`、`calendar.action` 等字段。
- Skill 与跨仓文档口径一致。

**Non-Goals**

- 不删除飞书 Hermes **对话**（plan 仍由 skill 编排）。
- 不碰 `integration-feishu-qa`、day-reminders EventKit。
- 不重命名 spec id（仍用 `hermes-learning-calendar`，改 Purpose/Requirements）。

## Decisions

1. **删除而非 feature-flag**：`feishu_enabled` 移除，不做静默禁用。
2. **遗留 `feishu_event_id`**：读取时忽略；写入新任务不再带该字段；不批量清历史（可选 migration 脚本在 tasks 里一步完成）。
3. **作废 `fix-learning-rollover-calendar`**：在 tasks 中标记 cancelled，不 apply。
4. **Hermes 母本**：更新 `~/.hermes/openspec/changes/build-hermes-learning-assistant-v1/proposal.md` 与 `learning-calendar-sync` spec 为 deprecated 说明（pointer 到本 change）。

## Risks / Trade-offs

- 用户若仍看飞书日历旧格 → 文档说明需手动清理一次性孤儿（skill 删 orphan 文档）。
- 破坏性：依赖 `calendar-sync` 的外部脚本失效 → 接受。

## Migration

- `profile.json`：删除三个 feishu/calendar 键。
- 现有 `projects.json` 任务可保留未知字段，schedule 不再读写在逻辑中引用。
