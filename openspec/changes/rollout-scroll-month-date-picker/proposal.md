## Why

`ScrollMonthDatePicker`（方案 C 纵向滚月）已在「项目截止日」Sheet 试点验证：触控板滑月、整格可点、双击确认均可用。其余选日期入口仍使用系统 `DatePicker`（Form compact、Menu 内嵌 graphical），体验不一致且 Menu 内嵌几乎无法操作。用户要求**全面替换**，但**必须保留各入口原有的呈现层级**——原地 Popover/Form 内联/既有 Sheet，不得统一改成屏幕正中弹新窗。

## What Changes

- 将 `ScrollMonthDatePicker` 提升为 Dashboard 级共享组件（自 `LearningDeskPanel` 迁出或抽公共层），供计划侧栏与学习面板共用。
- **计划 · 编辑提醒**（`DeskReminderEditSheet`）：在**现有 Sheet + Form 内**用滚月控件替换日期部分；若开启「指定具体时刻」，日期仍用滚月、时刻仍用 compact 时分选择（不改为新窗口）。
- **学习 · 添加任务**（`LearningInsertTaskSheet`）：在**现有 Sheet + Form 内**内联滚月，替换 `DatePicker`。
- **学习 · 任务改期**（`LearningTaskRow`，今日/日程两行）：移除 Menu 内 `DatePicker`；Menu 保留「推迟到明天」等文字项，「选择日期…」在 **⋯ 按钮原位 Popover** 展开滚月（不新增居中 Sheet）。
- **学习 · 项目截止日**（`LearningDeadlineEditSheet`）：已接入；本 change 仅做共享化/refactor 对齐（行为不变，含双击确认）。
- 组件行为统一：整格点击、`contentShape`、可选 `onDoublePick`（仅适用处有「确认」语义时启用）。
- **范围外**：右栏喝水/T7 **时分** `DatePicker`；智能提醒文本输入；计划侧栏「推迟到明天/+7 天」快捷按钮；**日程 Tab 顶栏月份浏览**（chevron 加载 `schedule-range`，非选截止日值——另 change 再议是否改为滚月导航条）。

## Capabilities

### New Capabilities

（无独立 capability；交互规范写入既有 spec。）

### Modified Capabilities

- `learning-desk-panel`：添加任务、任务改期、截止日编辑均使用滚月选日；改期须 Popover 原位展开。
- `desk-pet-controls`：计划侧栏编辑提醒 Sheet 内日期选择使用滚月选日，保持 Sheet 呈现不变。

## Impact

- **代码**：`ScrollMonthDatePicker.swift`（共享位置）、`DeskReminderEditSheet`、`LearningInsertTaskSheet`、`LearningTaskRow`、`LearningDeadlineEditSheet`（import 路径）、测试迁移/增补。
- **Hermes / EventKit**：无契约变更；仍输出/消费 `YYYY-MM-DD` 与现有 move/insert/set-deadline/save 流程。
- **前置**：依赖已落地的截止日试点实现；归档 change `scroll-month-deadline-picker` 可在 rollout 完成后一并处理。
