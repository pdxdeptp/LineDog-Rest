## Why

学习面板「今日 todo」在条目或分区高度变化时，仍可能用不同布局时刻的列表高度、输入行高度和可用高度反复改写 compact/pinned 状态，造成输入框晚 1～2 条贴底、拖动分隔线时短暂消失或重新出现。现有 change 尚未通过手动 QA，因此需要在归档前把方案从“多回调修补状态”改成由当前 Geometry 与同一轮内容测量共同驱动的稳定布局。

## What Changes

- **稳定输入框身份**：输入框在视图树中只有一个固定挂载点；compact/pinned 只改变列表 viewport 与滚动能力，不再把 `NSViewRepresentable` 在 ScrollView 内外迁移。
- **单一布局决策**：由纯 `TodayTodoLayoutPolicy` 根据列表实测高度、输入行实测高度和 Geometry 当前可用高度一次性解析布局，不再让条目计数、`sectionHeight`、draft 高度等多个回调直接写 `isDraftPinned`。
- **真实内容测量**：在实际 ScrollView 内容上测量列表尺寸，并把列表尺寸与输入行高度合并成一个完整 Preference snapshot；不复制隐藏的 `todoEntries` 视图树，也不使用固定 `estimatedRowHeight` 推测新增条目高度。内容变化最多等待下一份完整测量 snapshot，不等待新的用户操作。
- **确定性 viewport 布局**：纯 policy 明确返回 `measuring / compact / pinned`、固定列表 viewport 高度和滚动开关；compact 使用列表实高，pinned 使用扣除输入行后的完整 capacity，边界 tolerance 固定为 0.5pt。同步 `draftFieldHeight` 仅作为实测整行高度的安全下界，避免多行增长等待 Preference 时挤出输入框。
- **分隔线联动**：todo 内容区只信当前 Geometry 高度；移除基于外层 `sectionHeight` 旧快照的重算，也不向布局层传递 `splitDragInProgress` 或冻结拖动状态。
- **统一滚动锚定**：不区分新增、编辑、展开、分隔线或窗口缩放；任何 mode 转入 pinned 都无动画滚到底部锚点，任何 mode 转入 compact 都无动画归顶部锚点。
- **回归验证**：新增布局解析和测量 snapshot 单测，覆盖新增条目、分隔线缩放、可变行高和回调乱序；更新 presentation 契约并完成真实应用手动 QA。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `learning-desk-panel`: 今日 Tab 的 todo 分区必须用当前分区 Geometry 响应拖动和窗口缩放，不依赖父级拖动状态或旧高度快照。
- `learning-today-todo`: compact/pinned 布局改为单一输入框挂载点与真实内容高度驱动，确保首次溢出即贴底且切换不销毁输入框。

## Impact

- **MalDaze**：重构 `TodayTodoSection.swift`，新增 `TodayTodoContentLayout.swift`，调整 `TodayTodoLayoutPolicy.swift`；不修改 `LearningDeskPanelView.swift` 的现有 `sectionHeight` 接口。
- **测试**：扩展 `TodayTodoLayoutPolicyTests` 与 presentation tests，并补充运行中应用的拖动、连续添加、删除和焦点 QA。
- **Hermes / EventKit / JSON**：无契约、持久化或同步语义变更。
- **非目标**：不改变 todo 数据模型、软删除/历史、Hermes 分隔比例默认值、Dashboard 其它 resize handle 行为，也不在本 change 中增加上下分区的绝对最小高度约束。
