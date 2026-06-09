# MalDaze 实施任务 · v1（L1 + L2）

> L3 增删/Week/FSEvents/review → [add-learning-desk-panel-l3](../add-learning-desk-panel-l3/tasks-maldaze.md)

## 1. 工程脚手架

- [x] 1.1 新建 `MalDaze/LearningDeskPanel/` + xcodeproj
- [x] 1.2 `HermesScheduleModels.swift`（Today / Move / Complete 响应）
- [x] 1.3 `HermesScheduleCLI` 协议 + Process 实现（`HERMES_HOME`）
- [x] 1.4 `LearningDeskPanelViewModel`：`loadToday()` = rollover + today

## 2. Dashboard 三栏（L1）

- [x] 2.1 `DashboardLayout` 中栏 min 360pt + `minimumContentWidth`
- [x] 2.2 `DashboardRootView` 左 | `LearningDeskPanelView` | 右
- [x] 2.3 窄屏 clamp
- [x] 2.4 布局单测更新（若有）

## 3. Today 只读 UI（L1）

- [x] 3.1 `LearningDeskPanelView` + `LearningTodayView`
- [x] 3.2 顶栏预算/超额/休息日
- [x] 3.3 正课/复习列表 + warnings
- [x] 3.4 `auto_roll_days` 角标（自 `study.tasks` / `review.tasks` 合并）
- [x] 3.5 刷新；打开 Dashboard 自动 load
- [x] 3.6 空态 / Hermes 错误卡

## 4. complete（L2）

- [x] 4.1 Checkbox → `complete --task-id`
- [x] 4.2 成功刷新；失败展示 error
- [x] 4.3 写操作行级 disabled

## 5. move（L2 · 依赖 H-L2）

- [x] 5.1 推迟到明天 + 日期 picker
- [x] 5.2 `LearningMovePreviewSheet` + `move --dry-run`
- [x] 5.3 确认后 `move`；`calendar_errors` 次要提示
- [x] 5.4 拒绝时展示 Hermes error

## 6. 测试与验收（v1）

- [x] 6.1 Mock CLI 单测
- [x] 6.2 `integration_smoke` 仍全绿
- [x] 6.3 MANUAL_QA M-L-1～6（**不含** L3 项）
- [x] 6.4 ROADMAP §7.1 v1 行 → ✅
- [x] 6.5 `hermes.md` 登记表（面板 v1 已上线）
