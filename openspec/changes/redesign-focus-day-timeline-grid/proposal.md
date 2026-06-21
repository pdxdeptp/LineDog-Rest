## Why

P1「今日专注」以右栏逐条列表展示 session，挤占计时操作区，且与学习面板割裂。用户需要的是**中栏展示区**里、**类似 GitHub 的格子时间轴**：默认 **8:00–24:00**，**凌晨 0–8 点有学习则自动向左扩展**；每格 **30 分钟**，格内按 **`startedAt`→`endedAt`（或 `now`）与格时间的重叠比例** 用 **accent 蓝连续填色**（非整格开关、非 GitHub 四级离散；例：格内 3 分钟 = 10% 宽度）。明细仍只存 JSON。

## What Changes

- **移除** Dashboard 右栏 `FocusSessionTodaySection`（列表、提前结束文案、进行中文字行）。
- **新增** 学习面板 Today Tab header 内的 **比例填色格子时间轴**：
  - 默认可见 **08:00–24:00**；若当日 session 与 **00:00–08:00** 有重叠，可见起点自动对齐到最早相关格（30 分钟粒度，不早于 00:00）。
  - 固定 **30 分钟/格**；格内 **accent 蓝** 按比例子区域着色（`completed` / `stoppedEarly` / 进行中均参与）。
- **摘要** 同行 `N 个 · X 分钟`（`N` = 完整番茄；`X` = 总分钟）。
- **调整** Hermes 完成进度：`ProgressView` → 与小时负荷同行的 `完成 done/total`。
- **不变**：`focus-sessions.json`、Hermes 契约、右栏计时操作。

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `learning-desk-panel`: Today header 可扩展 accent 比例格子轴 + 内联完成数字。
- `desk-pet-controls`: 移除右栏专注列表。

## Impact

- **修改**: `LearningDeskPanelView.todayHeader`、`FocusDayTimelineCellGridView`（格内 accent 比例渲染）、`DashboardRootView`。
- **修改**: `FocusDayTimelineCellGridModel`（动态窗口 + 30min 格子 + overlap 并集），输入仍为 `AppViewModel` projection。
- **测试**: 窗口扩展、格内 overlap 比例（含 3min→10%）、presentation 断言。
