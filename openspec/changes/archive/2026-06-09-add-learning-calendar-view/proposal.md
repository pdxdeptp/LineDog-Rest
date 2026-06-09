## Why

学习面板已有「今日」列表与「周负荷」分钟条形图，但用户无法 **按日查看具体排了哪几节课**；改截止日 / repack 后尤其难发现 overflow 课仍落在截止日之后。需要 **双模式日程视图（月历缩略 + 按日议程）**，仍读 `projects.json`（经 CLI），不读飞书日历。

探索结论：用户选定 **方案 C**（上方月历导航 + 下方 Agenda 主视图）。母本：[learning-desk-panel.md](../../../docs/integrations/features/learning-desk-panel.md) · ROADMAP 新项 X8

## What Changes

### Hermes

- 新增 `schedule.py schedule-range`（名称暂定，见 design）：
  - 按日返回 **任务明细** + 负荷汇总（正课/复习分桶、休息日、超容量）。
  - 支持 `--from` / `--to` 或 `--month YYYY-MM`；默认覆盖 **当前月** 并延伸至各 active 项目 `deadline`（取较晚边界）。
  - 仅读 `projects.json` + `profile.json`；不访问飞书。

### MalDaze

- 将「周负荷」Tab **替换** 为「**日程**」Tab（方案 C）：
  - **上部**：当月迷你月历（可翻月）；格内显示任务数或负荷提示；标色：今日、休息、超容量、项目截止日。
  - **下部**：按日 **Agenda** 列表（日期标题 + 负荷条 + 当日任务行）；点击月历某日滚动/定位到对应 Agenda 段。
  - 任务行复用 Today 行组件能力（完成 / 推迟 / 复习通过失败），写操作仍走既有 CLI。
- 月历切换或 `projects.json` 变更后懒加载 / debounce 刷新 `schedule-range`。
- 标出 **deadline 之后仍排期的任务**（overflow 可视化），与项目 Tab `deadline_exceeded` 一致。

### 文档

- 更新 `learning-desk-panel.md` US 映射；`MANUAL_QA` 增 M-L10 日程验收项；`ROADMAP.md` 登记 X8。

## Capabilities

### New Capabilities

<!-- 无独立新 spec id；能力落在既有 learning + Hermes CLI -->

### Modified Capabilities

- `learning-desk-panel`: MODIFIED — 「周负荷」Tab 替换为「日程」双模式视图；交互与刷新链。
- `hermes-learning-calendar`: ADDED — `schedule-range` CLI 供面板按日拉取任务与负荷（JSON SSOT，非飞书）。

## Impact

- **Hermes**：`schedule.py` 新子命令 + 单测 + `integration_smoke` 条目。
- **MalDaze**：新 `LearningScheduleView`（月历 + Agenda）、ViewModel/Models/CLI、`PanelTab` 更名；移除或废弃对纯 `week-load` Tab 的依赖（CLI 可保留兼容）。
- **非目标**：飞书月历、拖拽排课、Swift 本地算排期、左栏 EventKit 合并。
- **依赖**：与 `add-learning-project-status`（deadline / repack）互补；可先合并 X7 再实施本 change。

## Affected Specs

- `learning-desk-panel`（delta MODIFIED + ADDED）
- `hermes-learning-calendar`（delta ADDED）
