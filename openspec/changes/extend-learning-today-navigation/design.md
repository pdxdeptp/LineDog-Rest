## Context

- 依赖 `extend-learning-today-core` 的双顶栏、分组、滚入区。
- 日程 Tab 已有 `schedule-range`；明日一瞥避免拉整月 JSON。
- 飞书/Hermes 对话用 `pending.index` 完成；晨报 listing 同序。

## Goals

- 诊断（落后、超额）→ 一键导航，不自动改 JSON（默认模式：只读 + 跳转）。
- 明日负荷可见，减少切 Tab。
- 学习任务与资料 URL 衔接。
## Non-Goals

- 面板顶栏「编号快完成」输入（飞书/晨报编号完成保留在对话侧；面板用行内勾选）。

## Non-Goals (continued)

- 智能模式方案卡；Focus/番茄；拖拽改期。

## D1: `tomorrow_preview`

`today` 响应追加：

```json
"tomorrow_preview": {
  "date": "2026-06-10",
  "pending_count": 3,
  "study_minutes": 145,
  "study_budget": 300,
  "tasks": [
    { "index": 1, "task_id": "...", "title": "...", "project_name": "...", "duration_minutes": 45 }
  ]
}
```

- `tasks` 最多 5 条，按明日 `build_pending_list` 顺序。
- 明日休息日：`is_rest_day: true`，`tasks: []`。

## D2: `source_url` on pending

- `build_pending_list` 附加项目级 `source_url`（可 null）。
- MalDaze：有 URL 时行内 `link` 图标，`NSWorkspace.open`。

## D3: 行动卡

触发：任一 `warnings.length > 0` 或今日正课/复习超额。

内容示例：

```
今日正课超额 · LC 落后 4 天
[今日只看 LC]  [打开日程·明天]  [项目 Tab]
```

- 「今日只看 LC」：设置分组过滤 `project_id`（ViewModel `todayProjectFilter`），非持久。
- 「打开日程·明天」：`selectedTab = .schedule`，`scheduleMonth` 对齐，`selectedScheduleDate = tomorrow`。
- 「项目 Tab」（**S3 · v1 必做**）：`selectedTab = .projects`，`scrollToProjectId = project_id`；`LearningProjectStatusView` 用 `ScrollViewReader` 滚到对应卡。
- 「重排未完成课」（**R2**）：对选中 `project_id` 调 `set-deadline --dry-run`（deadline 不变）→ 复用 deadline repack sheet → 确认后正式 `set-deadline` spread repack。

## D4: Warnings 点击

- 点击 warning 行 → `highlightTaskId` = 今日该 `project_id` 首条 pending；无则 `actionNotice` 提示「今日无该项目任务」。

## D5: 与晨报

- `hermes-morning-briefing` 已用 `today.pending`；本 change 仅文档确认 index 稳定。
- **必做 smoke（R1）**：`integration_smoke.check_schedule_today` 在 `pending` 非空时断言 `index == 1..pending_count`；可选交叉检查 `morning-briefing` 学习段 index 一致。

## Risks

| 风险 | 缓解 |
|------|------|
| tomorrow 计算与 schedule-range 不一致 | 共用 `_tasks_for_day` 逻辑或单测对比 |
| 行动卡按钮过多 | 最多 3 个主按钮 |
| URL 为空 | 无 link 图标 |

## Verification

- Hermes：`test_schedule_today_tomorrow_preview.py`
- MANUAL_QA M-L12-nav
