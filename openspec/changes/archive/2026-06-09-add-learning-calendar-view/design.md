## Context

- **现状**：`week-load` 仅返回每日 `total_minutes` / `budget` / `over_capacity`，无 `tasks[]`；`LearningWeekLoadView` 为 28 天条形列表。
- **痛点**：repack / 改 deadline 后，用户看不到「每天哪几节、哪些仍落在截止日后」；周负荷红条无课名。
- **约束**：P5 — 面板读 JSON（CLI），不读飞书日历；写操作仍仅 `schedule.py` 子命令。
- **用户选择**：探索阶段 **方案 C** — 月历缩略 + Agenda 主视图。

## Goals / Non-Goals

**Goals:**

- 中栏「日程」Tab：上月历、下 Agenda，看清 **每天安排**（课名、项目、时长、复习、休息、超容量）。
- 月历可翻月；点选日期定位 Agenda；今日 / 截止日 / overflow 可辨。
- Agenda 行支持 Today 同级轻交互（完成、推迟、复习）。
- Hermes 提供单次 CLI 拉取月范围 + 任务明细，避免 Swift 聚合 `projects.json`。

**Non-Goals:**

- 经典全屏月格内嵌多行课名（中栏太窄）。
- 拖拽改期、对话排课、读飞书日历、与左栏 EventKit 合并。
- 一次性展示全年；默认以 **月 + active 项目 deadline 延伸** 为界。
- 替换飞书日历 App 的周视图。

## Decisions

### D1: Tab 替换「周负荷」→「日程」

| 方案 | 选择 |
|------|------|
| 第四 Tab（今日/周负荷/日程/项目） | Tab 过多 |
| 保留周负荷 + 新增日程 | 信息重复 |
| **用日程取代周负荷**（Agenda 内含负荷条） | **选用** — 一条路径看清「量 + 课」 |

`week-load` CLI **保留**（兼容 / smoke），面板主路径改 `schedule-range`。

### D2: UI 布局（方案 C → **路线 1 修订**）

中栏实测：**迷你月历色点不可读**，改为 **翻月条 + Agenda 纯列表**（2026-06-08 产品决议）。

```
┌─────────────────────────────────────┐
│  ◀  2026年6月   [今天]  ▶          │
├─────────────────────────────────────┤
│ 6/9 周二 · 3 节 · 2.5h/3h · 超额    │
│   └ 力扣 · 第03集 …  77m            │
│ 6/17 周三 · 2 节 · 截止              │
│ 7/1 周三 · 1 节 · 超期 1            │
└─────────────────────────────────────┘
```

- **无月历格**；日标题用 **文字**（星期、课数、负荷、超额/截止/超期）。
- **今天** 按钮：切回当月并滚到今日段。
- **Agenda**：主信息区；`LearningTaskRow` 复用。
- **今日 Tab**：日后另开 change 细化，本 change 不碰。

### D3: Hermes `schedule-range` CLI

| 方案 | 选择 |
|------|------|
| 扩展 `week-load --include-tasks` | 响应变大、语义混杂 |
| **新子命令 `schedule-range`** | **选用** — 专为日历/议程 |

**参数（初版）：**

- `--from YYYY-MM-DD`（默认：当月 1 日）
- `--to YYYY-MM-DD`（默认：`max(当月最后一天, 各 active 项目 deadline)`）
- `--month YYYY-MM`（与 from/to 互斥，便捷翻月）

**每日条目：**

```json
{
  "date": "2026-06-11",
  "is_rest_day": false,
  "study_minutes": 171,
  "review_minutes": 30,
  "budget_study": 180,
  "budget_review": 60,
  "over_capacity": true,
  "tasks": [
    {
      "task_id": "lc_review_task_8",
      "project_id": "lc_review",
      "project_name": "力扣算法 · 基础算法精讲",
      "title": "第08集 · …",
      "duration_minutes": 53,
      "task_type": null,
      "status": "pending",
      "after_project_deadline": false
    }
  ]
}
```

- `tasks`：当日 `scheduled_date` 匹配、且 `status ∉ {completed, failed}`；排序：`scheduled_date` 已有同日，按 `project_id` + 任务列表顺序（与 `get_ordered_tasks` 一致）。
- `after_project_deadline`：该任务 `scheduled_date` > 所属项目 `deadline`（overflow 可视化）。
- 响应顶层含 `deadlines[]`：`{ project_id, name, deadline }` 供月历标截止日。

### D4: 范围与翻月

- 打开日程 Tab：加载 **当前月** range；若某 active `deadline` 在下月，**自动延伸 `to`** 至该 deadline（用户可看到 7 月 overflow 课）。
- 用户翻月：仅加载该月（仍 `to = max(月末, 月内涉及 deadline)`），避免一次拉全年。

### D5: 刷新链

- 切到日程 Tab → 若 cache miss 则 `schedule-range`。
- `projects.json` FSEvents（已有 debounce）→ 若当前 Tab 为日程则 refresh range（**不 rollover**）。
- 完成 / move / insert / remove / set-deadline 成功后：若日程 Tab 活跃或已缓存，invalidate 并 reload。

### D6: 交互深度

- Agenda 行 = Today 同行：checkbox、推迟、复习按钮；move 仍走预览 sheet。
- 月历格 **只读导航**，不在格内完成勾选。

## Risks / Trade-offs

- **[Risk] 中栏窄，月历 7 列拥挤** → 用小号字体 + 色点；Agenda 承担详情。
- **[Risk] 多月 deadline 延伸导致 payload 大** → 上限 `to` 不超过 `from + 93 天`；超出截断并响应 `truncated: true`。
- **[Risk] 与 week-load 行为漂移** → 超 cap 算法与 `week-load` / `validate` 同 profile 字段；单测对照同一 fixture。
- **[Risk] 多 active 项目** → 任务行显示 `project_name` 前缀；月历截止日用多色点或「最近 deadline」优先（初版：各 deadline 竖线标在月历上最后一天）。

## Migration Plan

1. Hermes `schedule-range` + 单测 → MalDaze 日程 Tab → 文档 / MANUAL_QA M-L10 → 归档。
2. 移除面板对 `week-load` 的 Tab 绑定；`LearningWeekLoadView` 可删或内联为 Agenda 子组件。
3. 无 `projects.json` 迁移。

## Open Questions

| ID | 决议 |
|----|------|
| 子命令名 | **`schedule-range`**（实现前可改为 `day-agenda`，文档统一即可） |
| 超 cap 判定 | 正课 > `daily_capacity_minutes` **或** 复习 > `review_budget_minutes`（与 validate 一致） |
| 失败任务 | 默认 **不展示**在 Agenda（与 week-load 一致）；后续可加筛选 |
