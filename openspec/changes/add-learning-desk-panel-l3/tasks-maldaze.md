# MalDaze · L3

> 前置：v1 `LearningDeskPanel/` 已存在。

## 1. insert / remove

- [ ] 1.1 行菜单「删除」+ 确认对话框 → `remove --task-id`
- [ ] 1.2 底栏或工具栏「添加任务」表单：title、duration、date、project（多项目 Picker）
- [ ] 1.3 `insert` 成功/失败处理 + refresh

## 2. Week Tab

- [ ] 2.1 Tab 切换：Today | Week
- [ ] 2.2 懒加载 `week-load`（或 Swift 聚合降级）
- [ ] 2.3 每日条形 + 超 cap 标红

## 3. FSEvents

- [ ] 3.1 监听 `projects.json`（路径随 `HERMES_HOME`）
- [ ] 3.2 debounce 1s → `loadToday()`（仅 today，不 rollover）
- [ ] 3.3 Dashboard 不可见时停止 watcher

## 4. review 行

- [ ] 4.1 review 行显示通过/失败按钮
- [ ] 4.2 `review --result passed|failed` + refresh

## 5. 验收

- [ ] 5.1 单测：FSEvents debounce mock（若可测）
- [ ] 5.2 MANUAL_QA 扩展（insert/remove/week/外部改 JSON）
- [ ] 5.3 ROADMAP §7.2 → ✅
