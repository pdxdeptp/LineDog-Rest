# Tasks: extend-learning-today-core

> **前置**：无（与 `extend-learning-today-navigation` 可串行；navigation 应在本 change 之后 apply）。

## 1. Hermes `today` progress

- [x] 1.1 `cmd_today` 输出 `progress.study/review { done, total }`
- [x] 1.2 `test_schedule_today_progress.py`（pending+completed 同日、仅 pending、休息日）
- [x] 1.3 `integration_smoke` 可选断言 `progress` 字段存在

## 2. MalDaze models & header

- [x] 2.1 解码 `HermesTodayProgress`；`LearningCapacityFormatting` 复习桶
- [x] 2.2 双预算顶栏 UI（正课 + 复习，分桶超额）
- [x] 2.3 完成进度条 `done/total`（正课 + 复习）
- [x] 2.4 `HermesScheduleModelsTests` 解码

## 3. 滚入置顶区

- [x] 3.1 `LearningTodayRolloverStrip`（≥3 天）；点击 `ScrollViewReader` 定位
- [x] 3.2 行内仍保留 ≥1 天 badge

## 4. 实际时长

- [x] 4.1 `complete --actual-minutes` 已接线 CLI
- [x] 4.2 行菜单「记录时长并完成」+ sheet
- [x] 4.3 ViewModel `complete(taskId:actualMinutes:)`

## 5. 项目分组

- [x] 5.1 扁平 / 按项目 Toggle（`AppStorage` 或 VM）
- [x] 5.2 分组段标题 + 段内 index 顺序

## 6. Docs & QA

- [x] 6.1 `learning-desk-panel.md` 今日核心增强；`ROADMAP` 登记
- [x] 6.2 `MANUAL_QA.md` M-L12-core
- [x] 6.3 `openspec validate extend-learning-today-core --strict`
- [ ] 6.4 用户 MANUAL_QA M-L12-core
