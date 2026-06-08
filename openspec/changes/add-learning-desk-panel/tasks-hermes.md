# Hermes 实施任务 · v1（H-L2 only）

> H-L1 rollover 日历 → [fix-learning-rollover-calendar](../fix-learning-rollover-calendar/tasks-hermes.md)  
> H-L3 / H-L4 → [add-learning-desk-panel-l3](../add-learning-desk-panel-l3/tasks-hermes.md)

## 1. move 预览（H-L2 · L2 阻塞项）

- [x] 1.1 `schedule.py move` 增加 `--dry-run`：输出 `changes[]`，不写盘、不 patch 日历
- [ ] 1.2 单测：dry-run 与 apply 的 `changes[]` 一致；dry-run 后 JSON 不变
- [ ] 1.3 `skills/learning-assistant/SKILL.md` 注明 MalDaze 面板使用同命令
