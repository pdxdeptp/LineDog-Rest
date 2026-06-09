## Context

当前选日期入口与**呈现方式**：

| 入口 | 文件 | 现状呈现 | 目标呈现 |
|------|------|----------|----------|
| 项目截止日 | `LearningDeadlineEditSheet` | Dashboard `.sheet` | **不变**（已滚月） |
| 编辑提醒 | `DeskReminderEditSheet` | Dashboard `.sheet` + Form | **不变 Sheet**；Form 内滚月 |
| 添加任务 | `LearningInsertTaskSheet` | Dashboard `.sheet` + Form | **不变 Sheet**；Form 内滚月 |
| 任务改期 | `LearningTaskRow` | `Menu` 内嵌 `DatePicker` | **Popover 锚定 ⋯**（原位） |
| 日程 Tab 顶栏 | `LearningScheduleView` | chevron 翻月 | **本 change 不改动** |

试点组件：`MalDaze/LearningDeskPanel/ScrollMonthDatePicker.swift`（含 `ScrollMonthDatePickerLogic`、整格 hit test、macOS 14+ scroll snap、可选 `onDoublePick`）。

## Goals / Non-Goals

**Goals:**

- 所有**选日历日**的 Dashboard 交互统一为 `ScrollMonthDatePicker`。
- **严格保留**各入口原有 presentation chrome（Sheet 仍 Sheet、Popover 仍锚定在触发控件旁、Form 仍内联）。
- 任务改期 Popover：选日后关闭 Popover → 走现有 `onPickDate` → `requestMove` dry-run → 既有 `LearningMovePreviewSheet`（不改其 Sheet 层级）。
- 共享组件单测覆盖 logic；各入口至少一条 presentation/行为测试或现有 VM 测试不退化。

**Non-Goals:**

- 不把改期/添加任务/编辑提醒改为**新的**屏幕居中 modal（若某处已是 Sheet 则保留）。
- 不替换时分 `DatePicker`（喝水安静时段、T7、提醒「指定具体时刻」）。
- 不在本 change 改日程 Tab 的月份数据导航（与「选截止日/改期日」不同问题）。
- 不引入快捷 chip 行（方案 F）除非某入口已有等价按钮。

## Decisions

### 1. 组件位置

**决定**：迁至 `MalDaze/ScrollMonthDatePicker/ScrollMonthDatePicker.swift`（与 feature 无关的 UI 模块），`LearningDeskPanel` 与 `Reminders` 均 `@testable import MalDaze` 使用。

**理由**：计划侧栏与学习面板同属 Dashboard，不应让 Reminders 依赖 LearningDeskPanel 子目录。

### 2. Presentation 封装

**决定**：核心视图保持单一 `ScrollMonthDatePicker`；各 call site 自行包 presentation：

- **Form / Sheet 内联**：直接嵌入 `ScrollMonthDatePicker(selection:)`，外裹 `Section` 或 `VStack`；不设额外 Popover。
- **任务改期**：`LearningTaskRow` 增加 `@State private var showDatePopover`；Menu 中 `Button("选择日期…") { showDatePopover = true }`；在 `Menu` label（⋯）上 `.popover(isPresented: $showDatePopover, arrowEdge: .trailing) { ScrollMonthDatePicker(...) }`。Popover 宽 ~320，高沿用 220pt。
- **禁止**：在 Menu 内嵌 picker；禁止为改期新建 `.sheet`。

**备选**：macOS `NSPopover` — 弃用，SwiftUI `.popover` 足够且与 Dashboard Panel 内坐标一致。

### 3. 选日回调语义

| 入口 | 单击 | 双击 |
|------|------|------|
| 截止日 Sheet | 更新 + dry-run preview | 确认（已有） |
| 编辑提醒 Sheet | 更新 draft.dueDate | 无（保存仍靠 toolbar） |
| 添加任务 Sheet | 更新 pickedDate | 无（提交靠「添加」） |
| 任务改期 Popover | 更新 + `onPickDate` + **dismiss popover** | 无（move 另有 preview sheet） |

### 4. 编辑提醒：日期 + 时刻

**决定**：`includesTimeInDueDate == false` 时仅滚月；为 true 时滚月 + 下方保留 compact `DatePicker(.hourAndMinute)` 绑定同一 `dueDate`（或拆 time 到 components 合并写回 draft）。

### 5. Form 布局

**决定**：滚月放入 Form 时用 `.listRowInsets` / 隐藏 DatePicker label 风格，避免 Form 再套一层系统 date picker 行。可用 `Section { ScrollMonthDatePicker... }.listRowBackground(Color.clear)` 减少双滚动冲突。

### 6. 与 `scroll-month-deadline-picker` 关系

截止日 Sheet 行为已验收；rollout 以**迁移 + 其余入口**为主，截止日仅改 import 路径与共享组件引用，不重写交互。

## Risks / Trade-offs

- **[Risk] Dashboard Panel 内 Popover 被 Panel 边界裁剪** → Popover 附在 ⋯ 上、`arrowEdge: .trailing`；若 clipped，改用 `.popover(attachmentAnchor: .rect(.bounds))` 微调；必要时 `presentationCompactAdaptation(.none)`（macOS）。
- **[Risk] Form 与滚月双 ScrollView 手势冲突** → Sheet 主体不整体包 ScrollView；滚月固定高度 220pt（已有）。
- **[Risk] 改期 Popover 选日立即触发 move preview** → 与现 Menu DatePicker `onChange` 一致；Popover dismiss 后再 async `requestMove`，避免 popover 生命周期问题。
- **[Trade-off]** 日程 Tab chevron 暂不统一 — 避免 scope 膨胀；用户若需要可开 follow-up change。

## Migration Plan

1. 移动/共享组件 + 更新 xcodeproj + 测试路径。
2. 接入三处（提醒 Form、添加任务 Form、任务 Popover）；截止日改 import。
3. 手动 QA 矩阵（见 tasks.md）。
4. 通过后可 archive `scroll-month-deadline-picker` 与 `rollout-scroll-month-date-picker`。

## Open Questions

- 无阻塞项。日程 Tab 滚月导航是否纳入 follow-up，待 rollout 手感反馈后再 propose。
