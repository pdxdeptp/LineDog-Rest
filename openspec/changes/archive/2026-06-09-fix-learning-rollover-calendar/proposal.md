> **CANCELLED (2026-06-08)**：学习域已移除飞书日历投影（`remove-feishu-learning-calendar`）。`schedule.py rollover` 仅更新 JSON；不再 patch 飞书日历。本 change **不实施、不归档**。

## Why（历史）

原问题：`rollover` 更新 JSON 但未 patch 飞书日历 `feishu_event_id`，导致日历格子与 JSON 不一致。

## 替代方案

- 移除全部学习域飞书日历集成 → `remove-feishu-learning-calendar`
- rollover 验收 → [MANUAL_QA.md](../../../docs/integrations/MANUAL_QA.md) 域 C · C-R1
