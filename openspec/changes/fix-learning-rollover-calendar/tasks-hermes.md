# Hermes · H-L1 rollover 日历同步

## 1. 实现

- [ ] 1.1 `cmd_rollover`：对 `rolled[]` 中有 `feishu_event_id` 的任务 patch 日历日期
- [ ] 1.2 复用 move 的 lark-cli patch/verify 辅助函数（抽公共或内联，避免漂移）
- [ ] 1.3 rollover JSON 输出增加 `calendar_errors[]`（patch 失败时）

## 2. 测试

- [ ] 2.1 单测：mock lark-cli 或隔离 fixture — JSON 滚入 + patch 调用参数正确
- [ ] 2.2 可选：`integration_smoke.py` `rollover_calendar_sync` 项

## 3. 文档

- [ ] 3.1 `skills/learning-assistant/SKILL.md` rollover 段注明日历 sync
- [ ] 3.2 `learning-calendar.md` 排查表：rollover 后日历旧日期 → 查本修复
- [ ] 3.3 ROADMAP H-L1 → ✅
