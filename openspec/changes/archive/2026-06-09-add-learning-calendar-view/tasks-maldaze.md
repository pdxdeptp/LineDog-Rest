# MalDaze · X8 · 日程 Tab（方案 C）

> **依赖**：`tasks-hermes` §1–2。

## 1. Models + CLI

- [x] 1.1 `HermesScheduleRangeResponse` / day / task 模型
- [x] 1.2 `HermesScheduleCLI.scheduleRange(from:to:month:)`
- [x] 1.3 解码单测 fixture

## 2. UI

- [x] 2.1 `LearningScheduleView`：月历头 + 7×N 格 + Agenda `ScrollViewReader`
- [x] 2.2 色点/标色：今日、休息、超 cap、deadline、overflow
- [x] 2.3 复用 `LearningTaskRow`（完成 / 推迟 / 复习）
- [x] 2.4 `PanelTab.week` → `.schedule`（「日程」）；移除 `LearningWeekLoadView` 独立 Tab 入口

## 3. ViewModel

- [x] 3.1 `scheduleState` 懒加载、翻月 reload
- [x] 3.2 FSEvents / 写操作后 refresh schedule（不 rollover）
- [x] 3.3 与今日 / 项目 Tab 刷新不打架

## 4. 文档与验收

- [x] 4.1 `MANUAL_QA` M-L10
- [x] 4.2 `openspec validate add-learning-calendar-view --strict`
