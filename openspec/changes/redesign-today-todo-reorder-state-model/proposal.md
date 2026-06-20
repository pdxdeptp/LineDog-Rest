## Why

当前两轮 today todo 拖拽改动把可变 `previewOrder` 与原始冻结 row frame 混用，并在 pressing 阶段重配正在接收鼠标事件的 AppKit 文字视图，导致插入槽位不稳定、邻行位移动画实际为零、落定回到源位置，以及拖动期间整列重复布局。继续调 spring 参数无法修复这些结构性问题，需要用单一、可证明的槽位状态模型替换现有实现。

## What Changes

- 用不可变 `baseOrder`、冻结 `slotFrames`、`sourceSlot` 与单一 `targetSlot` 表示一次拖拽；拖动期间不改变 `ForEach` 顺序，也不写 store。
- pressing 只展示轻量抓起反馈，保持原 AppKit 事件接收者挂载且可继续发送 `mouseDragged`；达到 4pt 阈值后才创建 placeholder 与浮层。
- 被拖浮层直接跟随 pointer；其他行仅根据 `sourceSlot → targetSlot` 派生位移，并对该位移做 spring 动画，形成真实的 2pt 插入缝。
- drop/cancel 分别计算明确的目标槽位 Y 与源槽位 Y；动画结束后才提交 `sortIndex` 或清理 session，禁止通过固定 delay 掩盖错误目标。
- 将高频 pointer 更新隔离到浮层渲染路径，避免每个 mouse event 触发全部 AppKit 文字行的属性重写、intrinsic-size 失效与 frame Preference 重算。
- pinned edge scroll 改用 viewport-local pointer Y 和实际增量滚动；滚动后平移/刷新冻结槽位位置，不再以 60Hz 反复 `scrollTo` 首尾项目。
- 增加状态机、连续跨槽/反向拖动、非零邻行位移、目标落定、AppKit 手势连续性、滚动坐标与渲染失效范围的回归测试。
- 本 change 取代尚未完成 Manual QA 的 `redesign-today-todo-drag-reorder` 与 `fix-today-todo-reorder-animation` 的拖拽设计；不叠加第三套兼容路径。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `learning-today-todo`: 将未完成条目拖拽排序的契约细化为固定槽位模型、连续手势、明确落定目标和有界渲染更新，并保留现有文字长按与 `sortIndex` 持久化行为。

## Impact

- **MalDaze**：重写 `TodayTodoReorderController`/session 与 `TodayTodoAnimatedReorderList` 的状态和渲染职责；调整 `TodayTodoInlineText` 的长按事件桥接；重做 `TodayTodoContentLayout` 的 edge scroll 接口。
- **测试**：扩充 controller 纯状态测试，新增 AppKit→session 手势集成测试、SwiftUI presentation/invalidations 约束和 pinned scroll 坐标测试。
- **文档/OpenSpec**：更新 learning today todo 拖拽语义，并在实现前明确旧两个未完成 change 被本 change 取代。
- **数据与集成**：不改变 `today-todo.json` schema、`sortIndex` 语义、Hermes 契约、compact/pinned policy 或 draft focus token。
