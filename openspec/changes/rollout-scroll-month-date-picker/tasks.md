## 1. 共享组件

- [x] 1.1 将 `ScrollMonthDatePicker.swift`（含 Logic）迁至 `MalDaze/ScrollMonthDatePicker/`，更新 `MalDaze.xcodeproj` 与测试 import
- [x] 1.2 确认整格点击、`contentShape`、220pt 高度、macOS 13/14 scroll 行为在迁移后不变
- [x] 1.3 截止日 Sheet 改引用共享路径；`onDoublePick` 确认行为回归

## 2. 计划 · 编辑提醒（Sheet + Form 内联）

- [x] 2.1 `DeskReminderEditSheet`：有截止日时 Form 内嵌 `ScrollMonthDatePicker` 替换日期 `DatePicker`
- [x] 2.2 保留「指定具体时刻」compact 时分 `DatePicker`；无截止日 Toggle 行为不变
- [x] 2.3 不新增 presentation 层级；仍为 Dashboard `.sheet(item:)`

## 3. 学习 · 添加任务（Sheet + Form 内联）

- [x] 3.1 `LearningInsertTaskSheet` Form 内嵌滚月替换 `DatePicker`
- [x] 3.2 提交 ISO 日期与 `insert` 流程不变

## 4. 学习 · 任务改期（Popover 原位）

- [x] 4.1 `LearningTaskRow`：移除 Menu 内 `DatePicker`；增加「选择日期…」+ `@State` popover
- [x] 4.2 Popover 锚定 ⋯，`ScrollMonthDatePicker`；选日后 dismiss 并调用 `onPickDate`
- [x] 4.3 禁止新增居中 Sheet；`LearningMovePreviewSheet` 确认流不变

## 5. 测试与验证

- [x] 5.1 迁移/增补 `ScrollMonthDatePickerLogicTests`；必要时加 Popover 触发纯逻辑测试（VM/row state）
- [x] 5.2 `xcodebuild test` 相关用例通过
- [ ] 5.3 手动 QA：四入口 presentation 对照表——改期 Popover 原位、其余 Sheet/Form 原位；无新增居中弹窗
