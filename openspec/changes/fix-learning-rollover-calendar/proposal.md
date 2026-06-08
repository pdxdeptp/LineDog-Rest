## Why

学习任务 SSOT 在 `projects.json`，飞书日历为软投影。`schedule.py rollover` 会把未完成昨日任务滚入今天并更新 JSON，但 **当前未 patch 关联 `feishu_event_id`**，导致日历格子仍停在旧日期——用户扫日历时与面板/飞书 today 不一致。

本 change 修复 **rollover → 日历同步** 缺口，与 MalDaze 面板 **无直接依赖**（面板不读日历），但改善飞书日历作为辅助视图的可信度。

**前置**：域 C C1/C2 已上线；可与 `add-learning-desk-panel` v1 并行实施。

总目录：[ROADMAP.md](../../../docs/integrations/ROADMAP.md) Phase 6c · 背景：[learning-calendar.md](../../../docs/integrations/features/learning-calendar.md)

## What Changes

### Hermes

- `cmd_rollover`：对每个滚入任务，若 `feishu_enabled` 且存在 `feishu_event_id`，patch 事件 `start_time`/`end_time` 到新 `scheduled_date`（与 `move` 日历逻辑一致）。
- 单测或 smoke：rollover 后 JSON 与日历日期一致（mock 或隔离环境）。
- skill 文档：rollover 会同步日历。

### MalDaze

- **无代码变更**（可选：排查表补一行）。

## Capabilities

### New Capabilities

- （无）

### Modified Capabilities

- `hermes-learning-calendar`: ADDED — rollover 保持日历投影与 JSON 日期一致。

## Impact

- **Hermes**：`schedule.py` `cmd_rollover`；`tests/` 或 smoke。
- **MalDaze**：无。
- **风险**：patch 失败应记入输出（类似 `move` 的 `calendar_errors`），不阻断 rollover 写 JSON。

## Affected Specs

- `hermes-learning-calendar`（delta ADDED）
