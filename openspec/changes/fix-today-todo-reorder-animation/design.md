# Design · fix-today-todo-reorder-animation

## Context

当前实现路径：

```text
InlineNotesTextView.mouseDragged
  → TodayTodoReorderController.updateDrag(event:)
  → listCoordinateView.pointerY(from:)   // 0×0 NSView, AppKit Y-up
  → 与 GeometryReader rowFrames 比较     // SwiftUI Y-down
  → overlay.offset + row.offset(animation: insertionIndex)
  → endDrag: reset() → store.reorderIncomplete()
```

已确认问题：

1. **0×0 coordinate anchor** 使 `convert(...).y` 不能代表列表内指针位置。
2. **AppKit vs SwiftUI Y 轴** 混用，insertion 与 overlay offset 失效。
3. **动画绑错对象**：`.animation(..., value: insertionIndex)` 不管 `dragPointerY`；overlay 无抓起/放下 spring。
4. **松手 instant commit**：`reset()` 在 spring 落定前清空状态，ForEach 瞬间重排。
5. **pinned edge scroll** 使用 top/bottom 硬跳，加剧拖动脱节。

约束：macOS 13；不改 `today-todo.json`；不改 compact/pinned policy；长按 350ms + 4pt 与单击编辑分工不变；不写 store 直到落定动画完成。

## Goals / Non-Goals

**Goals:**

- 抓起、拖动、放下/取消三阶段动画可感知且跟手。
- pointer Y 与 row frame 在同一 list 坐标系（top-left pt）。
- 拖动中仅 preview 顺序变化；persist 在 settling 结束后。
- pinned 下边拖边滚为连续 nudge。
- apply 前固定 phase 状态机、动画参数、坐标转换公式。

**Non-Goals:**

- 恢复 ≡ 手柄或 DropDelegate。
- 改 Hermes / 分隔线 / layout policy。
- 已完成组排序、排序模式开关。
- 120fps Core Animation 自定义 layer（首版仍用 SwiftUI spring + 跟手 offset）。

## Decisions

### D1 · 单一 list 坐标系

**删除** `TodayTodoListCoordinateAnchor.swift` 作为 pointer 源。

**新增** `TodayTodoListPointerReader.swift`：

- `NSViewRepresentable` 覆盖 `TodayTodoAnimatedReorderList` 的 **整个列表区域**（非 0×0）。
- `mouseDragged` 中将 window 坐标转为 list 坐标：

```text
listPointerY = listBounds.height - convert(windowPoint).y   // AppKit local → SwiftUI top-left
```

- 与 `TodayTodoRowFramePreferenceKey` 同用 `.named("todayTodoReorderList")` 等价的 view bounds。

行 frame 在 `beginDrag` 时 **冻结** 为 `frozenRowFrames: [UUID: CGRect]`，拖动中 insertion 只用 frozen 快照，不用 offset 后的实时 Preference（避免反馈环）。

### D2 · Session 状态机（preview / persist 分离）

重命名/重构 `TodayTodoReorderController` → `TodayTodoReorderSession`：

```text
enum Phase { idle, pressing, dragging, settling, cancelling }

State:
  phase
  sourceEntryId, sourceIndex
  previewOrder: [UUID]          // 拖动中唯一顺序
  insertionIndex: Int           // 0...count，由 listPointerY 对 frozen frames 算出
  listPointerY: CGFloat
  grabOffsetY: CGFloat          // beginDrag: listPointerY - frozenFrame.midY
  frozenRowFrames: [UUID: CGRect]
  frozenRowHeights: [UUID: CGFloat]
```

**Phase 转移：**

| 事件 | 转移 |
|------|------|
| long-press 350ms 到 | idle → pressing（spring scale/shadow 渐入） |
| move ≥ 4pt | pressing → dragging |
| mouseUp, index 变化 | dragging → settling → commit → idle |
| mouseUp, index 不变 | dragging → idle |
| Esc / 无效区域 | dragging → cancelling → idle |
| 单击 | 不进入 pressing |

**persist 时机**：仅 `settling` 动画 completion 或 spring 结束回调后调用 `store.reorderIncomplete(fromSource:toInsertionIndex:)`，再清 session。

### D3 · 三阶段动画

常量（与 prior change 一致）：

```text
springResponse = 0.32
springDamping = 0.86
insertionGap = 2pt
longPressDuration = 0.35s
dragStartThreshold = 4pt
```

| 阶段 | 被拖行 | 其它行 | store |
|------|--------|--------|-------|
| pressing | placeholder opacity 1→0.3；overlay 待现 | 不动 | 不写 |
| dragging | overlay `y = frozen.minY + (listPointerY - grabOffsetY - frozen.midY)` **无 spring** | `previewOrder` 变化时 `withAnimation(spring)` offset 让位 + 2pt gap | 不写 |
| settling | overlay spring 合并回目标 slot | 同步 spring | 动画后写 |
| cancelling | overlay spring 回 source | spring 还原 previewOrder | 不写 |

**禁止**在 `TodayTodoContentLayout` mode/viewport 上使用 `withAnimation`。

### D4 · insertionIndex 与 previewOrder

```text
insertionIndex(listPointerY, frozenFrames, previewOrder):
  for (i, id) in previewOrder.enumerated():
    if listPointerY < frozenFrames[id].midY: return i
  return previewOrder.count
```

当 `insertionIndex` 变化且 phase == dragging：

```text
withAnimation(spring) {
  previewOrder.move(sourceId to insertionIndex)  // 每次只移一项，不多次写 store
}
```

邻行 `gapOffset` 由 preview 中 index 与 insertion 关系推导，不再用 sourceIndex 对 store 数组。

### D5 · 渲染结构

```text
TodayTodoAnimatedReorderList
└─ ZStack(alignment: .topLeading)
   ├─ TodayTodoListPointerReader(onPointerY:, onDragPhaseEvents:)
   ├─ VStack  // layout + measurement
   │  └─ ForEach(previewOrder) { id in
   │       row.opacity(id == dragging ? 0 : 1)
   │         .offset(y: gapOffset(for: id))
   │     }
   └─ if phase >= dragging
       overlay(row).offset(...).scaleEffect(lift).shadow(...)
```

`todoEntries` 外层 `TodayTodoMeasuredGeometryKey` 仍测 **layout VStack** 总高；placeholder 保留高度，pinned 不抖。

### D6 · pinned 连续 edge scroll

替换 ContentLayout 中 `scrollTo(top/bottom)` timer：

- Preference `TodayTodoReorderEdgeScrollKey` 仍为 -1/0/1。
- ContentLayout 收到非 0 时，每 1/60s `scrollTo(neighborEntryId, anchor: .center)`，方向由 edgeScrollDirection 决定。
- reorder session 提供 `nearestScrollTargetId(for: direction)` 基于 frozen frames 与 viewport。

### D7 · 手势（AppKit 侧小改）

`InlineNotesTextView` 保留 350ms + 4pt；`mouseDragged` 只转发 event 给 `TodayTodoListPointerReader` 或 session，**不再**调用 `listCoordinateView.pointerY`。

### D8 · 测试

1. **Unit**：`insertionIndex` + flipped Y 转换（mock frames + pointerY → expected index）。
2. **Unit**：`previewOrder` move 不调用 store until settling。
3. **Presentation**：无 `TodayTodoListCoordinateAnchor`；有 `TodayTodoListPointerReader`、`previewOrder`、`Phase.settling`。
4. **Manual QA**：跟手、让位 spring、松手落定、Esc 回弹、pinned 边拖边滚。

## Risks / Trade-offs

- **[Risk] settling 时长与 spring 参数难对齐** → 用固定 response/damping + `animationCompletionCriteria`（macOS 14+）或 conservative delay；macOS 13 用 spring duration 估算 ~0.35s 后 commit。
- **[Risk] previewOrder 与 store 短暂不一致** → 仅 dragging/settling 窗口；UI 只读 previewOrder。
- **[Risk] 冻结 frame 与 scroll 后错位** → edge scroll 时可选 refresh frozen Y offsets only，不 remeasure 高度。

## Migration Plan

1. 新增 pointer reader + session phase；单测坐标/insertion（RED）。
2. 改 AnimatedReorderList 三阶段渲染；拖动不写 store。
3. 删除 CoordinateAnchor；改 edge scroll。
4. 手动 QA；更新 docs。

回滚：revert session/list/reader；不涉及 JSON。

## Open Questions

- 无（settling 在 macOS 13 上用 spring duration 估算 commit 时机，不引入新依赖）。
