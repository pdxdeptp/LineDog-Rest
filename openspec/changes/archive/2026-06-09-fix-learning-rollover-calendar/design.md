> **CANCELLED (2026-06-08)**：superseded by `remove-feishu-learning-calendar` — rollover updates JSON only; no calendar patch.

## Context

- 学习域飞书日历投影 **已移除**（2026-06-08+）。
- `rollover` 仅更新 `scheduled_date`、`auto_roll_days`；不调用外部日历 API。

## 现行行为

- JSON rollover **始终**成功；验收见 [MANUAL_QA.md](../../../docs/integrations/MANUAL_QA.md) 域 C · C-R1。

## 历史备注

本 change 曾计划复用 `move` 的 lark-cli patch；该代码路径已在 `remove-feishu-learning-calendar` 中删除。
