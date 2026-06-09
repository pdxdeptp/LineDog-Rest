## Why

项目截止日修改 Sheet 目前使用 SwiftUI `.graphical` `DatePicker`，在 macOS 上只能点小箭头翻月，无法双指滑动，选 distant 截止日操作成本高。用户已在 HTML demo 中选定**方案 C（纵向滚月）**作为试点，需先在截止日这一处自研替换以验证手感，再决定是否推广到其他选日场景。

## What Changes

- 新增可复用的 SwiftUI 组件 `ScrollMonthDatePicker`（纵向 ScrollView + 按月 snap + 点选日期）。
- 在 `LearningDeadlineEditSheet` 中用该组件替换 `.graphical` `DatePicker`。
- 保持现有行为不变：`onDateChange` 触发 dry-run preview、确认/取消、`canConfirm` 逻辑、Hermes `set-deadline` 调用链。
- **范围外（本 change 不做）**：提醒编辑、任务改期、日程 Tab 翻月、快捷 chip、其他 DatePicker 替换。

## Capabilities

### New Capabilities

（无 — 交互组件为实现细节，需求增量写入既有 capability。）

### Modified Capabilities

- `learning-desk-panel`：截止日编辑 Sheet 的日期选择交互从系统 graphical 日历改为纵向滚月自研控件，并明确支持触控板/滚轮翻月。

## Impact

- **代码**：`MalDaze/LearningDeskPanel/`（新 picker 组件 + `LearningDeadlineEditSheet`）、`MalDaze.xcodeproj`、可选单元/UI 测试。
- **Hermes / 契约**：无 API 变更；仍输出 `YYYY-MM-DD` ISO 字符串。
- **其他 DatePicker 调用点**：不受影响。
