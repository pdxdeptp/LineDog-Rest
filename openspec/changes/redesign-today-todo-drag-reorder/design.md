# Design · redesign-today-todo-drag-reorder

## Context

当前实现（`TodayTodoReorderDropDelegate` + 行首 `line.3.horizontal` + `onDrag`）能在 macOS 13 上完成排序，但存在三类问题：

1. **视觉**：左侧多一列 ≡，行宽变窄，与「备忘录式随手记」不一致。
2. **动效**：AppKit 拖放在 `dropEntered` 时直接改写数组顺序，无连续跟手、无邻行让位。
3. **手势冲突**：文字区由 `InlineNotesTextView`（AppKit）负责单击进入编辑；若简单把 `onDrag` 挂到文字上，会与编辑抢占同一手势。

约束：目标 macOS 13；不改变 `today-todo.json` schema；不修改 `TodayTodoContentLayout` 的 measuring/compact/pinned policy；排序不得递增 `draftFocusRequestToken` 或触发 mode 切换动画。

## Goals / Non-Goals

**Goals:**

- 未完成条目 ≥ 2 时，用户 **长按文字区** 即可抓起排序，全程 spring 动画。
- 行布局无额外手柄；单击文字仍 inline 编辑。
- 排序结果持久化到 `sortIndex`；与 pinned 列表 auto-scroll、内容测量 Preference 共存。
- apply 前设计层固定：长按阈值、插入指示、动画参数、AppKit/SwiftUI 手势分工。

**Non-Goals:**

- 已完成组内排序、跨组拖放、排序模式开关。
- 修改 Hermes/分隔线/compact-pinned 阈值。
- iOS 或跨平台拖放；List `.onMove` 替换整个 todo 树（与 ScrollView 嵌套和测量架构冲突）。

## Decisions

### D1 · 文件与职责

| 文件 | 职责 |
|---|---|
| `TodayTodoReorderController.swift` | 拖动状态机：`draggingEntryId`、`dragTranslation`、`insertionIndex`、commit/cancel |
| `TodayTodoRowFramePreferenceKey.swift`（或合入 Controller 文件） | 各行 `CGRect` 聚合，仅 incomplete 列表使用 |
| `TodayTodoAnimatedReorderList.swift` | 包裹未完成 `ForEach`：overlay 被拖行、邻行 offset 动画、auto-scroll |
| `TodayTodoRow.swift` | 去掉 ≡/`reorderDragProvider`；文字区接长按入口 |
| `TodayTodoInlineText.swift` | AppKit 侧长按检测与「未达阈值不进入编辑」 |
| `TodayTodoSection.swift` | 组装 reorder list；删除 `onDrop`/`draggingEntryId` 旧路径 |
| `TodayTodoReorderDropDelegate.swift` | **删除** |

`TodayTodoStore.moveIncomplete` 保留；拖动结束只调用 store，不在 UI 层 duplicate 排序逻辑。

### D2 · 交互：单击编辑 vs 长按排序

**默认常量（产品默认，可在 apply 前微调 ±50ms）：**

```text
reorderLongPressDuration = 0.35s
reorderDragStartThreshold = 4pt   // 长按后移动超过此值才抓起
```

**规则：**

| 用户动作 | 结果 |
|---|---|
| 快速单击文字 | `onBeginEdit`（现有） |
| 按住文字 ≥ 350ms 且移动 ≥ 4pt | 进入排序：抓起当前行，不进入编辑 |
| 按住但未达 350ms 即松手 | 视为单击，进入编辑 |
| 行正在 inline 编辑 | 忽略排序手势 |
| 未完成条目 ≤ 1 | 不注册长按排序 |
| 点击 checkbox / 删除 | 不变 |

**AppKit 优先调度（D2 实现路径）：**  
在 `InlineNotesTextView.mouseDown/mouseDragged/mouseUp` 内做 long-press 计时与阈值判断；未确认排序前 **不** 调用 `onBeginEditingWithEvent`。SwiftUI 外层不再叠 `LongPressGesture`，避免与 `NSTextView` 事件顺序打架。

### D3 · 视觉与动画

**抓起（排序激活）：**

- 被拖行：`scale(1.02)`，`shadow(radius: 8, y: 2, opacity: 0.12)`，`zIndex` 置顶。
- 光标：`NSCursor.closedHand`（拖动）/ `openHand`（悬停可拖区，optional）。

**拖动中：**

- 被拖行：相对列表容器跟手（`dragTranslation`）。
- 插入位置：目标槽位出现 **2pt 垂直间隙**（非细线，便于与 spring 让位配合）。
- 其它行：对 `insertionIndex` 变化做 **`spring(response: 0.32, dampingFraction: 0.86)`** offset。
- **禁止**用 `withAnimation` 包裹 `TodayTodoContentLayout` 的 mode/viewport 变化。

**松手：**

- spring 落到目标槽位 → `store.moveIncomplete` → 清状态。
- **Esc** 或指针离开列表有效区域：spring 回原位，不写盘。

### D4 · 插入 index 计算

每个 incomplete 行通过 `TodayTodoRowFramePreferenceKey` 上报 frame（列表坐标系）。

```text
insertionIndex ∈ [0, count]
  0 = 第一行之前
  count = 最后一行之后
```

指针 Y 与各 row midY 比较，确定落在哪两行之间；拖动过程中 index 变化驱动邻行动画。  
**不在 `dropEntered` 时改 store**；仅在 `dragEnded` 且 index 相对起始变化时 persist。

### D5 · 与 pinned / 测量共存

- `TodayTodoRowFramePreferenceKey` 与 `TodayTodoMeasuredGeometryKey` **分离**，避免 reduce 互相覆盖。
- 排序 overlay 不参与 list 高度测量（被拖行仍占原槽位 placeholder，高度不变，避免 pinned 测量抖动）。
- pinned 且 `listScrollEnabled`：指针 Y 距 ScrollView viewport 上下缘 **≤ 8pt** 时 auto-scroll（~120pt/s），与现有 bottom-anchor-on-grow 逻辑独立。
- 排序开始/结束 **不** 改变 `resolution.mode`、不 scroll 到 top/bottom anchor。

### D6 · 测试策略

1. **Store**：保留/扩展现有 `moveIncomplete` 单测。
2. **Presentation**：无 `line.3.horizontal`、`TodayTodoReorderDropDelegate`；存在 `TodayTodoReorderController`/`TodayTodoAnimatedReorderList`。
3. **手动 QA**：长按 vs 单击、编辑中不拖、pinned 边拖边滚、松手持久化、Esc 取消。

## Risks / Trade-offs

- **[Risk] AppKit 长按与编辑时序复杂** → 在 `InlineNotesTextView` 单点实现计时；加 manual QA 矩阵；必要时记录 mouseDown 位置供 threshold 使用。
- **[Risk] 行 frame Preference 每帧更新开销** → 仅在 incomplete 列表且 count ≥ 2 时启用；拖动结束停止高频更新。
- **[Risk] placeholder + overlay 在 pinned 下 clip** → overlay 画在与 ScrollView 同级或 clip aware 容器；QA 验证最底行拖起可见。
- **[Risk] 用户未 discover 长按** → 无手柄；首版不做 coach mark；若反馈弱可考虑 hover 时 subtle cursor hint（Non-Goal 首版不做）。

## Migration Plan

1. 实现新 Controller + AnimatedReorderList + AppKit 长按。
2. 删除 ≡、`TodayTodoReorderDropDelegate`、Section 上 `onDrop`。
3. 跑单测与手动 QA；更新 learning-desk-panel 文档。
4. 回滚： revert 新文件 + 恢复 DropDelegate 路径（不涉及 JSON 迁移）。

## Open Questions

- 无（350ms / 2pt 间隙 / spring 参数为 apply 默认；若 QA 需调整，仅改常量不改架构）。
