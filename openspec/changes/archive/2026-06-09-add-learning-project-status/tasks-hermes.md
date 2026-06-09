# Hermes · X7 + US-10 · deadline repack

> **依赖**：现有 `set-deadline` 骨架；本阶段 **重写 repack 语义**。

## 1. Repack 核心

- [x] 1.1 `repack_incomplete_tasks(project, new_deadline, from_date)`：顺序填充，正课/复习分桶
- [x] 1.2 `cmd_set_deadline` 默认：写 deadline → repack → 响应 `changes[]` / `overflow_*`
- [x] 1.3 `--dry-run`：预览不写盘；`--no-repack`：仅改 deadline（面板不用）
- [x] 1.4 repack 后 JSON 响应含 `changes[]` / `overflow_*`（无日历投影）

## 2. 单测（替换旧「日期不变」测例）

- [x] 2.1 改 deadline 后 pending 任务 `scheduled_date` 变化；completed 不变
- [x] 2.2 容量不足 → `overflow_tasks` / `overflow_count`
- [x] 2.3 `dry-run` 不写盘；`--no-repack` 行为
- [x] 2.4 更新 `test_schedule_set_deadline.py` + `integration_smoke`

## 3. 文档

- [x] 3.1 `SKILL.md`：`set-deadline` 默认 repack 说明
- [x] 3.2 `schedule.py` docstring
