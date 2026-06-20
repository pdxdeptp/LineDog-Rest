## Why

手动番茄模式目前只驱动休息节奏，不持久化每次专注；用户无法回顾「今天完成了几个番茄、各段起止时间」，也无法为后续与学习任务、Todo 标注建立时间 SSOT。本 change 先落地 **P1：记录 + 可视化**，以番茄 session 为核心指标，学习任务时长等关联能力明确延后。

## What Changes

- 手动番茄模式下，每次**工作段结束**（自然进入休息，或专注中停止计时）写入一条本地 `FocusSession`（含 `startedAt`、`endedAt`、`durationMinutes`）。
- MalDaze 本地 JSON 持久化全部历史 session（不截断天数）；Dashboard 右栏展示**当日**番茄列表与汇总。
- 汇总行：`N 个番茄 · 共 X 分钟`（不区分完整/提前结束个数）；列表行时间格式 `HH:mm–HH:mm`；提前结束单行标注「提前结束」。
- 专注进行中在列表顶部显示 live 行（`HH:mm–进行中 · 已 N 分钟`）；进行中段不计入番茄个数，但计入汇总分钟（含已进行时长）。
- **不做**：Pin、手动贴标签、学习任务/Todo 关联、Hermes 写入、整点模式 session、历史浏览 UI、编辑/删除 session。

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `desk-pet-controls`: 新增手动番茄 focus session 持久化与 Dashboard「今日专注」可视化；不改变现有计时引擎 stop/resume/模式切换契约与 persistence keys。

## Impact

- **新增**: `FocusSession` 模型、`FocusSessionStore`（或等价模块）、`focus-sessions.json` under Application Support/MalDaze。
- **修改**: `AppViewModel`（工作段生命周期 hook）、`DashboardRootView` 右栏 UI。
- **测试**: store 持久化/日期过滤/进行中 live 状态；可选 presentation 断言。
- **无影响**: Hermes `schedule.py` / `daily_log.json`、现有番茄 duration UserDefaults keys、自动整点模式行为。
