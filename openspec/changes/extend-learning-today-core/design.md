## Context

- 今日数据链：`rollover` → `today` JSON → `LearningTodaySnapshot`。
- 已完成记录 SSOT：`daily_log.json` 按日的 `completed_tasks[]`；`projects.json` 任务 `status: completed`。
- 滚入：`auto_roll_days` 已在 `pending[]`；项目落后：`warnings[]`（首条 incomplete 早于今天 ≥3 天）。

## Goals

- 顶栏回答「今天塞多满、做了多少」。
- 滚入债一眼可见，不必在扁平列表里找。
- 完成可记实际时长，默认低摩擦。
- 多项目今日列表可分组扫读。

## Non-Goals

- 明日预览、行动卡、外链、编号完成（navigation change）。
- 滚入置顶区不提供推迟/完成（**S1**）；完整操作仅在主列表。
- 修改排期算法；智能模式提议。

## D1: `today` 进度字段

在 `cmd_today` 输出增加：

```json
"progress": {
  "study": { "done": 2, "total": 5 },
  "review": { "done": 0, "total": 1 }
}
```

算法：

- `total` = 今日 `scheduled_date` 且非 failed 的任务数（含已完成与仍 pending），按 study/review 分桶。
- `done` = 上述集合中 `status == completed` 的数量。
- 与 `study.total_minutes`（仅 pending 分钟）并存；UI 用 `progress` 做 X/Y，用 buckets 做负荷。

## D2: 双预算顶栏

- 正课：`study.total_minutes` / `daily_capacity_minutes`（Settings 同步）。
- 复习：`review.total_minutes` / `review_budget_minutes`（profile 默认 60）。
- 任一桶 `total_minutes > budget` → 标红 + 「超额」。

## D3: 滚入置顶区

- 筛选：`pending` 中 `auto_roll_days >= 3`（与晨报点名阈值对齐；badge 仍对 ≥1 显示在行内）。
- 置顶区在顶栏与主列表之间；任务仍在主列表展示（避免「完成了却不知道在哪」）或主列表排除置顶项二选一 → **保留在主列表**，置顶区为副本快捷入口（设计选：置顶区仅摘要+快捷按钮，点击滚动到主列表对应 id）。

**决策**：置顶区显示紧凑行，点击滚动 `ScrollViewReader` 到主列表 `task_id`；不重复完整菜单。

## D4: 实际时长

- 默认：单击圆圈仍一键完成（计划时长），保持快路径。
- 长按或菜单「完成并记录时长」→ sheet：Stepper/文本，默认 `duration_minutes`，确认后 `complete --actual-minutes N`。

## D5: 项目分组

- `@AppStorage` 或 ViewModel：`todayGrouping: flat | byProject`。
- `byProject`：按 `project_name` 排序分段；段内保持 `pending.index` 顺序。

## Risks

| 风险 | 缓解 |
|------|------|
| progress total 与用户直觉不符 | 单测：pending+completed 同日任务 |
| 置顶区与主列表重复 | 置顶仅摘要+跳转 |
| 复习预算用户不知存在 | 顶栏始终展示复习桶 |

## Verification

- Hermes：`test_schedule_today_progress.py`
- MalDaze：Models 解码 + ViewModel 分组逻辑
- MANUAL_QA M-L12-core
