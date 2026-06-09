## Context

- **前置**：v1 面板已有三栏、CLI 层、Today、complete、move+dry-run。
- **用户故事**：v2 US-13（周负荷）、US-15（增删）、复习行操作；非 v1 主环但提升日常可用性。

## Goals / Non-Goals

**Goals:**

- 面板内 insert/remove（不级联，与 `schedule.py` 一致）。
- Week Tab 只读负荷（**小时**展示）；优先 `week-load` CLI；超额按 MalDaze 设置上限标红。
- 每日学习上限：**MalDaze 设置 → 学习面板**，默认 **5 小时**，同步 Hermes `profile.json`。
- FSEvents 监听 `projects.json`，debounce 1s 刷新 Today。
- 复习任务行：通过/失败按钮。

**Non-Goals:**

- 拖拽 Gantt、对话调整、智能模式。
- `today_learning.json` 快照（ROADMAP X5）。
- rollover 仅更新 JSON（`remove-feishu-learning-calendar` 已移除飞书日历投影）。

## Decisions

### D1: Week 数据来源优先 H-L4

| 方案 | 选择 |
|------|------|
| Swift 直读 `projects.json` 聚合 | v1.1 降级可行 |
| `week-load` CLI | **首选** — 与 validate 超 cap 逻辑一致 |

### D2: FSEvents 仅触发 `today`（不自动 rollover）

打开面板时已 rollover；后台 JSON 变更（飞书改计划）只需 `today` 刷新。用户跨日首次打开仍走 v1 的 rollover+today。

### D3: insert 项目选择

- 数据来源：`schedule.py status` 全部 `status == active` 项目（不要求今日有任务）。
- 菜单式 Picker；无 active 时表单提示去 Hermes 创建项目。

### D6: 每日上限展示与设置

- CLI 仍用分钟（`total_minutes` / `budget`）；MalDaze 面板统一 **小时** 文案。
- `MalDazeDefaults.learningDailyCapacityHours` 默认 5.0；设置页 1–12h、步进 0.5。
- 保存时写 `profile.json` `daily_capacity_minutes`；启动时若 profile 与设置不一致则对齐。

### D4: remove 确认

二次确认对话框；文案含任务标题；无级联提示（D20）。

### D5: review 按钮仅 `task_type == review` 行

- 通过 → `review --result passed`
- 失败 → `review --result failed`（Hermes 生成下次复习）

## Risks / Trade-offs

- **[Risk] FSEvents 频繁写入** → debounce 1s；写操作成功后仍主动 refresh，避免双跑。
- **[Risk] week-load 与面板加载叠加延迟** → Week Tab 懒加载，切 Tab 才 spawn。

## Migration Plan

1. H-L4 + H-L3（Hermes，可并行）→ MalDaze L3 UI → MANUAL_QA 扩展项 → 归档。

## Open Questions

| ID | 默认 |
|----|------|
| Week 默认 14 还是 28 天？ | 28（对齐 v2 日历视图精简） |
| insert 是否支持从剪贴板粘贴标题？ | 否，v1.1 仅表单 |
