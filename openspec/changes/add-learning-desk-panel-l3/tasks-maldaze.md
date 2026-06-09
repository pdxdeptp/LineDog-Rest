# MalDaze · L3

> 前置：v1 `LearningDeskPanel/` 已存在。

## 1. insert / remove

- [x] 1.1 行菜单「删除」+ 确认对话框 → `remove --task-id`
- [x] 1.2 底栏或工具栏「添加任务」表单：title、duration、date、project（多项目 Picker）
- [x] 1.3 `insert` 成功/失败处理 + refresh

## 2. Week Tab

- [x] 2.1 Tab 切换：Today | Week
- [x] 2.2 懒加载 `week-load`（或 Swift 聚合降级）
- [x] 2.3 每日条形 + 超 cap 标红

## 3. FSEvents

- [x] 3.1 监听 `projects.json`（路径随 `HERMES_HOME`）
- [x] 3.2 debounce 1s → `loadToday()`（仅 today，不 rollover）
- [x] 3.3 Dashboard 不可见时停止 watcher

## 4. review 行

- [x] 4.1 review 行显示通过/失败按钮
- [x] 4.2 `review --result passed|failed` + refresh

## 5. 每日上限（小时 + 设置）

- [x] 5.1 默认 5 小时；今日顶栏 + Week Tab 以小时展示
- [x] 5.2 设置 → 学习面板滑杆（1–12h，步进 0.5）→ 同步 `profile.json`
- [x] 5.3 insert 项目列表来自 `status` 全部 active 项目

## 6. 验收

- [x] 6.1 单测：FSEvents debounce mock（若可测）
- [x] 6.2 MANUAL_QA 扩展（insert/remove/week/设置上限/外部改 JSON）
- [x] 6.3 ROADMAP §7.2 → ✅（目视通过；**未归档**）
