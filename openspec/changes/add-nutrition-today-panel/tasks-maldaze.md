# MalDaze · nutrition today panel

> 前置：Hermes `_refresh_panel` + `refresh-panel` 可产出含 `items[].name/grams` 的 `panel`

## 1. 契约 & CLI

- [x] 1.1 `NutritionDailyLogContract`（含钠、`suggestions.items`）
- [x] 1.2 `NutritionHermesCLI`：`log(name:grams:)` 子进程封装
- [x] 1.3 `NutritionDailyLogContractTests`
- [x] 1.4 `NutritionTodayViewModelTests`：扁平序号映射、>9 项、isLogging 互斥

## 2. FSEvents & ViewModel

- [x] 2.1 `NutritionDailyLogFileWatcher` debounce ~1s
- [x] 2.2 `NutritionTodayViewModel`：`loggableItems` 扁平序号、`logItem(flatIndex:)`、`isLogging` 互斥
- [x] 2.3 `NutritionDigitKeyMonitor`（S7-K）：Dashboard local monitor `1`–`9`；文本焦点/Sheet 时禁用
- [x] 2.4 45s `updatedAt` 轮询兜底（S2）

## 3. UI & Dashboard 布局

- [x] 3.1 `NutritionTodayPanelView`：序号前缀、`按 1–9 快捷记录`、行点击、记录中态
- [x] 3.2 `DashboardRootView` 左栏：持久化 **计划高度比例（S6，默认 0.6）**
- [x] 3.3 `MalDaze.xcodeproj` 新文件

## 4. 设置

- [x] 4.1 `MalDazeDefaults` + **设置页左栏比例滑杆（S6）** clamp 40–75% 计划区

## 5. 文档 & QA

- [x] 5.1 `nutrition-today-panel.md`；`hermes.md` · `ROADMAP` X2
- [x] 5.2 `MANUAL_QA.md` M-N1+（含点击记录、钠、比例、smoke）
- [x] 5.3 `openspec validate --strict`

## 6. 用户验收

- [ ] 6.1 点击与按 `2` 等效 log → 1s 内刷新；文本框聚焦时数字不触发；smoke 绿
