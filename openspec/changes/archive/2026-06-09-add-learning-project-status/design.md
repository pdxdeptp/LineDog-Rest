## Context

- **已实现（待改）**：`set-deadline` 仅写 `deadline`；面板 sheet 文案写「不移动任务」。
- **用户诉求**：改截止日后，**剩下没完成的课要重排**进新窗口。
- **可复用**：`plan` 的顺序填充、`available_days`。

## Goals / Non-Goals

**Goals:**

- `set-deadline` **默认 repack** 该项目未完成课程。
- 算法：**今天 → 新 deadline** 间的可用非休息日；任务按 `get_ordered_tasks` 中未完成条目的 **原列表顺序** 依次塞入；正课/复习分桶容量。
- 已完成课程 **不改日期**。
- 面板确认前说明会重排；可选 `dry-run` 预览 `changes[]`。
- repack 后刷新 today / week / status。

**Non-Goals:**

- 跨项目批量重排。
- 改 deadline 时增删任务、改时长、重新 plan 全新课表。
- 面板内 `--no-repack` 开关（仅 CLI 调试）。
- non-active 项目改 deadline。

## Decisions

### D0: `set-deadline` = 写 deadline + repack（默认）

| 方案 | 选择 |
|------|------|
| 仅改 deadline（现实现） | 与用户诉求不符 |
| 新子命令 `repack-deadline` | 面板要多记一条命令 |
| **`set-deadline` 默认含 repack** | **选用** — 用户心智「改截止日 = 重新排课」 |

`--no-repack`：仅改 `deadline` 字段，供脚本/回滚；MalDaze **不暴露**。

### D1: Repack 算法（与 `plan` 同族）

1. 收集该项目 `get_ordered_tasks` 中 `status ∉ {completed}` 的任务（含 `pending`、`failed`）。
2. `from_date = today`（本地日历日）；`days = available_days(from_date, new_deadline, profile)`。
3. 按任务在步骤 1 中的顺序遍历：
   - `task_type == review` → 占用当日 `review_budget_minutes`
   - 否则 → 占用当日 `daily_capacity_minutes`
   - 当日容量不够 → 推进下一可用日
   - 无可用日可放 → 进入 `overflow_tasks`（保留任务，**不改** `scheduled_date` 或标为 overflow 策略见下）
4. 对成功分配的任务写入新 `scheduled_date`；清除 `auto_roll_days` / `last_auto_rolled_at`（视为新排期）。
5. **Overflow 策略**：装不下的任务 **保持原 scheduled_date**，列入 `overflow_tasks`，`overflow_count > 0`，`deadline_exceeded` 按 validate 规则计算。

### D2: 响应 JSON

```json
{
  "project_id": "lc_review",
  "name": "力扣算法 · 基础算法精讲",
  "old_deadline": "2026-07-16",
  "new_deadline": "2026-08-15",
  "repacked": true,
  "changes": [
    { "task_id": "lc_review_task_2", "title": "…", "old_date": "2026-06-08", "new_date": "2026-06-09" }
  ],
  "overflow_count": 0,
  "overflow_tasks": [],
  "deadline_exceeded": false
}
```

`--dry-run`：同上但 **不写盘**。

### D3–D9

（项目 Tab、status 缓存、跳转今日等 — 保持 X7 已实现行为。）

### D8: Deadline 编辑 UI（更新）

- 按钮 → sheet → 选日 → **确认文案**：
  - 「将截止日改为 **M/D**，并**从今日起重排**该项目未完成的 N 节课（已完成不变）。」
- 若实现 dry-run：确认按钮上方显示「将移动 K 节课」或折叠 `changes` 列表（首 3 条）。
- 成功后：刷新 today + week + status；`overflow_count > 0` → 橙色提示「有 N 节课未能排进新截止日前」。

### D10: 与旧 US-10（v2 嵌入版）差异

- 原 v2 嵌入后端：deadline 编辑 **不** 移动任务。
- **本产品决策**：桌面面板改 deadline **默认 repack**；在 design 与 `learning-desk-panel.md` 明确记载，避免与旧 v2 文档混淆。

## Risks / Trade-offs

- **[Risk] 重排幅度大** → dry-run 预览 + 确认文案；可选展示 changes 条数。
- **[Risk] 今日已完成/进行中的课被挪走** → 已完成不动；仅 `pending`/`failed` 进入 repack 池。
- **[Risk] 新 deadline 太紧** → `overflow_tasks` + 明确提示，不静默失败。
- **[Risk] 单测/现实现冲突** → `tasks-hermes` 2.x 重写；旧「日期不变」测例改为 `--no-repack` 或删除。

## Migration Plan

1. 更新 OpenSpec / feature 文档（本步）→ Hermes repack + 单测 → MalDaze 文案/预览/刷新 → MANUAL_QA M-L9 修订 → 归档。

## Open Questions

| ID | 决议 |
|----|------|
| 面板是否必须 dry-run 预览？ | **P1**：首版可仅文案确认；有精力则做 changes 条数 |
| repack 起点 | **今天**（非「第一条未完成日」） |
| overflow 任务 | **保持原日期** + 响应列出 |
