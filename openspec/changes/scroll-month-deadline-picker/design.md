## Context

`LearningDeadlineEditSheet`（`LearningProjectStatusView.swift`）使用 SwiftUI `DatePicker` + `.datePickerStyle(.graphical)`。macOS 上该控件月份切换依赖小 chevron，不符合桌宠 Dashboard 触控板使用习惯。HTML demo（`docs/demos/date-picker-alternatives.html`）中方案 C 为纵向连续月列 + scroll snap，用户选定仅在此 Sheet 试点。

当前 Sheet 已 wired：
- `pickedDate` → `onDateChange(iso)` 触发 `previewDeadlineRepack`
- 确认走 `onConfirm` → `set-deadline`
- `canConfirm` 依赖 ISO 比较与 preview 计数

## Goals / Non-Goals

**Goals:**

- 提供 `ScrollMonthDatePicker`：纵向滚动、按月 snap、点选单日、选中态与「今天」高亮。
- 打开 Sheet 时 scroll 定位到**当前选中月**（初始为项目现有截止日或 today）。
- 替换 `LearningDeadlineEditSheet` 内 graphical DatePicker，保留 preview/confirm 语义。
- 支持 macOS 触控板双指纵向滑动与鼠标滚轮翻月（ScrollView 原生行为 + snap）。

**Non-Goals:**

- 不替换其他 5 处 DatePicker / 日程 chevron。
- 不引入第三方日历库。
- 不改变 Hermes CLI、preview API、overflow 文案逻辑。
- 不做快捷 chip（方案 F）或 Menu→Popover 重构（方案 G）。

## Decisions

### 1. 组件位置与命名

**决定**：`MalDaze/LearningDeskPanel/ScrollMonthDatePicker.swift`（同模块，Deadline Sheet 专用入口；API 设计为可复用 `@Binding var selection: Date`）。

**理由**：首版 scope 小，放 LearningDeskPanel 避免过早抽象到全局 UI 层；文件名与 change 一致便于后续推广。

### 2. 滚动实现

**决定**：`ScrollView` + `LazyVStack` 渲染 N 个月块（默认 anchor 月 ±12，共 ~25 个月），每块内嵌 7×6 网格；`.scrollTargetLayout()` + `.scrollTargetBehavior(.viewAligned)`（macOS 14+，与项目 Swift 版本一致时启用）；iOS 不可用时不影响本 macOS 桌宠 app。

**备选**：`ScrollViewReader` + 手动 `scrollTo` —  snap 手感差，弃用。

### 3. 月份网格

**决定**：复用与 demo 相同的网格算法（周日为首列、`zh_CN` 星期缩写、当月/邻月灰显、选中 accent、today 描边），封装为 `ScrollMonthDatePicker` 内部 private 视图或 small helper。

**理由**：与 HTML demo 视觉一致，用户已审阅；不依赖 `DatePicker`。

### 4. 选中与回调

**决定**：`@Binding var selection: Date`；点击日期 `Calendar.current.startOfDay` 写回 binding。Sheet 继续 `.onChange(of: pickedDate)` 调 `onDateChange(iso)` — **不在 picker 内调 Hermes**。

### 5. 初始 scroll 位置

**决定**：`onAppear` / `scrollPosition`（或 `ScrollViewReader.scrollTo`）定位到 `selection` 所在月 id。

### 6. 尺寸

**决定**：固定可视高度 ~220pt（与 demo wheel 区一致），宽度填满 Sheet；Sheet `minWidth` 保持 340。

## Risks / Trade-offs

- **[Risk] 外层 Sheet 也有 ScrollView 时滚动手势冲突** → Sheet 主体用 `VStack` 固定 picker 高度，不把整 Sheet 包在大 ScrollView 里（现状已是 VStack）。
- **[Risk] 远于 ±12 月的截止日** → 打开时动态扩展 window 以包含 selection 月；或按需 prepend/append（首版：初始化 range 以 selection 为中心 ±12）。
- **[Risk] `.viewAligned` 在旧 macOS 不可用** → 部署目标若 ≥14 仅用新 API；否则 fallback 无 snap 但仍可滚轮翻月。
- **[Trade-off]** 一次只见约 1 个月，不如 graphical 全览 — 换得流畅翻月。

## Migration Plan

1. 实现组件 + 单测（网格、ISO 边界）。
2. 替换 Sheet 内 DatePicker；本地 build + 手动 QA：学习/项目 → 修改截止日。
3. 无数据迁移；回滚 = 恢复 graphical DatePicker 一行。

## Open Questions

- （无阻塞项）推广到其他场景留待本 change 归档后用户反馈。
