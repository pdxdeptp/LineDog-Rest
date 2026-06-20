## Why

`redesign-today-todo-drag-reorder` 已去掉 ≡ 手柄并接入长按排序，但手动体验仍差：拖动时浮层不跟手、邻行不让位、松手瞬间跳序，几乎看不到设计中的 spring 动画。根因是 **0×0 AppKit 坐标锚点 + AppKit/SwiftUI Y 轴不一致** 导致 pointer Y 与行 frame 不可比，以及 **松手 instant reset + 直接写 store** 跳过了抓起/落定动画。需要在不改变 `sortIndex` 契约、长按编辑分工和 pinned 布局的前提下，修复坐标与三阶段动画管线。

## What Changes

- **统一 list 坐标系**：用覆盖整个未完成列表的 pointer reader 输出 SwiftUI top-left 坐标；删除 0×0 `TodayTodoListCoordinateAnchor` 作为主 Y 源。
- **preview / persist 分离**：拖动中只改 `previewOrder`；松手 spring 落定后再 `reorderIncomplete` 写盘。
- **三阶段动画**：抓起（scale/shadow 渐入）→ 拖动（overlay 1:1 跟手 + 邻行 spring 让位 + 2pt 缝）→ 放下/取消（spring 落定或回弹）。
- **冻结行高快照**：`beginDrag` 时缓存各行 frame/height，避免 Preference 重算与 scroll 导致跳变。
- **pinned 连续 edge scroll**：替换 `scrollTo(top/bottom)` 硬跳为按帧 nudge 相邻 row id。
- **测试**：pointer Y + insertionIndex 单测；presentation 断言删除错误坐标锚点、存在 `previewOrder` / settling phase。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `learning-today-todo`: 细化「文字区长按动画排序」的跟手、让位、落定/取消动画与坐标语义，使规范可验收。

## Impact

- **MalDaze**：重构 `TodayTodoReorderController`（或 `TodayTodoReorderSession`）、`TodayTodoAnimatedReorderList`；新增 `TodayTodoListPointerReader`；删除 `TodayTodoListCoordinateAnchor`；微调 `TodayTodoContentLayout` edge scroll。
- **测试 / 文档**：新增坐标与 insertion 单测；更新 learning-desk-panel §4.4 动画语义。
- **JSON / Hermes**：无变更。

## Affected Specs

- `learning-today-todo`（delta）

## Related Changes

- 建立在 `redesign-today-todo-drag-reorder` 之上；不恢复 ≡ 手柄或 AppKit `onDrop` 路径。
