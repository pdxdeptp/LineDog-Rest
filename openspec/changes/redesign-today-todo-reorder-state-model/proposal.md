## Why

当前两轮 today todo 拖拽改动把可变 `previewOrder` 与原始冻结 row frame 混用，并在 pressing 阶段重配正在接收鼠标事件的 AppKit 文字视图，导致插入槽位不稳定、邻行位移动画实际为零、落定回到源位置，以及拖动期间整列重复布局。继续调 spring 参数无法修复这些结构性问题，需要用单一、可证明的槽位状态模型替换现有实现。

## What Changes

- 用不可变 `baseOrder`、冻结 `rowFrames`、`sourceIndex` 与单一 `targetIndex` 表示一次拖拽；拖动期间不改变 `ForEach` 顺序，也不写 store。
- pressing 只展示轻量抓起反馈，保持原 AppKit 事件接收者挂载且可继续发送 `mouseDragged`；达到 4pt 阈值后才创建 placeholder 与浮层；350ms 后未达 4pt 松手回 idle 且不进入编辑。
- dragging 有效区域 = 列表 viewport ∩ 未完成列表 bounds（window 坐标）± **12pt**；越界、Esc、entries identity 变化或 view teardown 均 cancel 且不得 commit。
- 被拖浮层直接跟随 pointer；其他行仅根据 `sourceIndex → targetIndex` 的 `projectedGeometry` 做 spring 让位（视觉空隙来自邻行位移，不改变 measured list height）；overlay layer 额外绘制 **不参与布局测量的 2pt 目标槽位指示器**（非旧版 `insertionGap` 式物理撑开列表高度）。
- drop/cancel 分别计算明确的目标槽位 Y 与源槽位 Y；动画结束后才提交 `sortIndex` 或清理 session，禁止通过固定 delay 掩盖错误目标。
- 将高频 pointer 更新隔离到浮层渲染路径，避免每个 mouse event 触发全部 AppKit 文字行的属性重写、intrinsic-size 失效与 frame Preference 重算。
- pinned edge scroll 改用 viewport-local pointer Y 和实际增量滚动；滚动后用最后一个 window point 重算 content-local pointer，不重测槽位高度，也不再以 60Hz 反复 `scrollTo` 首尾项目。
- 增加状态机、连续跨槽/反向拖动、非零邻行位移、目标落定、AppKit 手势连续性、滚动坐标与渲染失效范围的回归测试。
- 本 change 取代尚未完成 Manual QA 的 `redesign-today-todo-drag-reorder` 与 `fix-today-todo-reorder-animation` 的拖拽设计；不叠加第三套兼容路径。
- 本 change 自包含地 **新增** animated reorder requirement；最终归档前必须先完成并归档基础 capability change `add-learning-today-todo`，且不得归档上述两个已被取代的 reorder change。

## Capabilities

### New Capabilities

（无新 capability 名称；本 change 向既有 `learning-today-todo` capability **新增** animated reorder requirement。）

### Modified Capabilities

（无。reorder requirement 尚未存在于 canonical specs；旧 change `redesign-today-todo-drag-reorder` 与 `fix-today-todo-reorder-animation` 未归档且由本 change 取代，因此 delta 类型为 **ADDED**，不是 MODIFIED。）

## Archive Prerequisites

1. **必须先归档** `add-learning-today-todo`，将 `learning-today-todo` capability 写入 canonical specs。
2. **然后**才可归档本 change（将其 ADDED reorder requirement 合并进 canonical）。
3. **不得归档** `redesign-today-todo-drag-reorder` 与 `fix-today-todo-reorder-animation`；验收后以 superseded 方式删除或保留为历史 artifacts。

## Impact

- **MalDaze**：重写 `TodayTodoReorderController`/session 与 `TodayTodoAnimatedReorderList` 的状态和渲染职责；调整 `TodayTodoInlineText` 的长按事件桥接；重做 `TodayTodoContentLayout` 的 edge scroll 接口。
- **测试**：扩充 controller 纯状态测试，新增 AppKit→session 手势集成测试、SwiftUI presentation/invalidations 约束和 pinned scroll 坐标测试。
- **文档/OpenSpec**：更新 learning today todo 拖拽语义，明确基础 capability 的归档前置关系，以及旧两个未完成 reorder change 被本 change 取代。
- **数据与集成**：不改变 `today-todo.json` schema、`sortIndex` 语义、Hermes 契约、compact/pinned policy 或 draft focus token。
