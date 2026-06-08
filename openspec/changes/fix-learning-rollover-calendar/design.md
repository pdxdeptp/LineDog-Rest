## Context

- `move` 已 patch/delete 日历；`complete` 默认 delete。
- `rollover` 更新 `scheduled_date`、`auto_roll_days`，**跳过** review 任务滚入规则见现有实现。
- 用户案例：JSON 任务已滚到 6/08，日历仍显示 6/05。

## Goals / Non-Goals

**Goals:**

- rollover 后，有 `feishu_event_id` 的滚入任务，日历事件日期与 JSON 一致。
- JSON rollover **始终**成功；日历失败 fail-soft + `calendar_errors` 数组。

**Non-Goals:**

- 为无 `feishu_event_id` 的任务 create 新事件（可运维 `calendar-sync`）。
- MalDaze 读日历。
- 批量清孤儿（C5 运维文档已有）。

## Decisions

### D1: 复用 move 的 patch 路径

对滚入任务调用与 `cmd_move` 相同的 lark-cli patch + 可选 verify，避免两套日历代码。

### D2: 仅 patch 实际发生日期变更的任务

rollover 输出 `rolled[]`；只对该列表中有 `feishu_event_id` 的项 patch。

### D3: review 任务

若 rollover 逻辑不滚 review，则日历 patch 也不涉及 review（保持现状）。

### D4: 输出 JSON

`rollover` stdout 增加可选 `calendar_errors[]`（与 move 同形），供 smoke/运维。

## Risks / Trade-offs

- **[Risk] lark-cli 失败** → JSON 已更新；stderr/JSON 记录；不 rollback JSON。
- **[Risk] 大量任务滚入** → 串行 patch；个人规模可接受。

## Migration Plan

1. 实现 patch → 单测 → 手工：制造昨日未完成任务 → rollover → 查日历日期。
2. 归档；更新 ROADMAP H-L1 → ✅。

## Open Questions

（无）
