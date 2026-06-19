# Tasks: add-learning-today-todo

> **前置**：无 Hermes 依赖。MalDaze-only change。

## 1. Data model & store

- [x] 1.1 新增 `TodayTodoEntry` / `TodayTodoFile` Codable 模型（`id`, `title`, `dateISO`, `rolledFromDateISO`, `isCompleted`, `createdAt`, `completedAt`, `sortIndex`）
- [x] 1.2 实现 `TodayTodoStore`：Application Support 路径、`loadAndRollForward()`、原子写盘
- [x] 1.3 Store CRUD：`add`, `toggleComplete`, `updateTitle`, `delete`, `historyGroupedByDate()`
- [x] 1.4 损坏/缺失 JSON 降级：解码失败 → 错误态 + 禁用 mutating

## 2. Unit tests

- [x] 2.1 `TodayTodoStoreTests`：add / complete / delete / 空标题拒绝
- [x] 2.2 顺延：昨日未完成 → load 后 `dateISO == today` 且 `rolledFromDateISO` 保留
- [x] 2.3 历史分组：仅 `dateISO < today && isCompleted`；不含已顺延未完成项
- [x] 2.4 文件损坏时 store 进入 error 态

## 3. UI components

- [x] 3.1 `TodayTodoRow`：checkbox、删除线、菜单（编辑/删除）、顺延 hint
- [x] 3.2 `TodayTodoSection`：标题「今日 todo」+「历史」、未完成列表、折叠「已完成 N」、`TextField` + 回车提交（随 ScrollView）
- [x] 3.3 `TodayTodoHistorySheet`：按日期分组倒序、只读列表 + 单条删除
- [x] 3.4 `.deskPetDashboardEscapeOverlay` for history sheet（对齐 learning panel 其它 sheet）

## 4. Integration

- [x] 4.1 嵌入 `LearningDeskPanelView.loadedBody`：`todayTaskList` 与 `tomorrowPreview` 之间
- [x] 4.2 `.task` / `onAppear` 调用 `todayTodoStore.loadAndRollForward()`（与 Hermes load 并行，不阻塞）
- [x] 4.3 确认 Hermes 失败 / 休息日 / 空任务时 Section 仍渲染
- [x] 4.4 确认 ↻ 刷新不触发 today todo 重载

## 5. Docs & validation

- [x] 5.1 更新 `docs/integrations/features/learning-desk-panel.md` 今日 todo 小节
- [x] 5.2 `docs/integrations/MANUAL_QA.md` 域 C 增 M-L-today-todo 验收清单
- [x] 5.3 `openspec validate add-learning-today-todo --strict`
- [ ] 5.4 用户 MANUAL_QA M-L-today-todo
