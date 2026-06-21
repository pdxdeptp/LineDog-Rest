## Context

现有拖拽链路横跨 AppKit `NSTextView` 事件、SwiftUI 列表布局、Preference frame 测量、ScrollView 和 JSON store。当前实现同时维护 `previewOrder`、`insertionIndex` 与按 entry id 冻结的 frame；`previewOrder` 改变后，frame 的遍历顺序不再对应空间顺序。pressing 又会把源行改成 placeholder，从而在同一次 mouse tracking 中关闭事件源。最终表现为抓起消失、邻行不让位、跨行抖动、drop 回源后跳序，以及 pointer 高频更新触发全列表 AppKit 重排。

约束：macOS 13；保留文字区 350ms 长按 + 4pt 位移阈值；不恢复拖拽手柄或 DropDelegate；不改变 `today-todo.json`、`sortIndex`、Hermes、compact/pinned policy 或 draft focus token；实现发生在当前未提交改动之上，必须原位替换旧路径，不能新增兼容分支。

本设计取代 `redesign-today-todo-drag-reorder` 与 `fix-today-todo-reorder-animation` 中尚未通过 Manual QA 的拖拽设计。animated reorder requirement 由本 change 以 `ADDED` delta 自包含定义；旧 reorder artifacts 不应归档进 canonical specs。`learning-today-todo` capability 仍由 `add-learning-today-todo` 引入，因此实现可先进行，但最终归档本 change 前必须先完成并归档 `add-learning-today-todo`。新 change 验收后再由用户决定删除或保留旧 reorder artifacts。

## Goals / Non-Goals

**Goals:**

- 一次拖拽只有一个空间真相：不可变的初始槽位快照和一个最终目标索引。
- pressing、dragging、settling、cancelling 每个阶段都有可观察且连续的视觉行为。
- pointer 每像素更新只影响轻量浮层；列表只在目标索引变化时更新。
- 连续跨多行、反向拖动和 pinned edge scroll 都产生稳定、可逆的目标索引。
- store 只在目标落定动画实际完成后写入，并以无动画 handoff 消除 commit 跳变。

**Non-Goals:**

- 已完成条目排序、跨组拖放、排序模式开关或触屏支持。
- 修改 today todo 数据模型、Hermes 契约或面板布局阈值。
- 为拖拽引入第三方动画/手势依赖。
- 在拖动期间支持同时编辑、删除、完成或外部重载同一列表。

## Decisions

### D1 · 固定槽位 session，而不是可变 preview 顺序

一次激活后的 session 保存：

```text
phase: idle | pressing | dragging | settling | cancelling
baseOrder: [UUID]                 // 激活时冻结，拖动期间不可变
sourceIndex: Int
targetIndex: Int                  // 移除 source 后的最终 0-based 索引
rowFrames: [UUID: CGRect]         // content-local、top-left
rowHeights: [UUID: CGFloat]
grabOffsetY: CGFloat
lastWindowPoint: CGPoint
```

`ForEach` 在 dragging/cancelling/settling 期间始终使用 `baseOrder`。不再存在会驱动结构换序的 `previewOrder`。最终顺序是纯派生值：

```text
projectedOrder = baseOrder.removing(sourceId).inserting(sourceId, at: targetIndex)
```

选择该模型是因为 slot geometry 与 identity order 始终同源，可对连续移动和反向移动做纯函数测试。拒绝“每次跨线先修改 previewOrder、再用原 frame 继续算”的方案，因为它会立即破坏 frame Y 的单调性；也拒绝拖动中重测 offset 后的 row frame，因为会形成 Preference → state → layout → Preference 反馈环。

### D2 · 目标索引只由剩余行的空间顺序决定

激活时将 row frame 按 `minY` 排序并验证与 `baseOrder` 一致。计算目标时：

1. 用 `pointerContentY - grabOffsetY + draggedHeight / 2` 得到浮层中心 Y。
2. 从候选 frame 中排除 source entry。
3. 按候选 frame 的原始空间顺序比较 `midY`；第一个大于浮层中心的候选位置就是 `targetIndex`，否则为候选数量。
4. 在相邻 midpoint 周围使用 `targetHysteresis = 2pt`；只有越过方向对应的边界才改变 target，避免临界像素往返抖动。

`targetIndex` 的范围固定为 `0...(count - 1)`，语义始终是最终数组索引。提交 store 时按 dragged id + final index 操作，不再向持久层传递会受 source 偏移影响的 insertion boundary。

### D3 · projected geometry 是邻行与落定位置的共同来源

`projectedGeometry(baseOrder, rowFrames, rowHeights, sourceId, targetIndex, spacing)` 是纯函数：按 `projectedOrder` 和冻结高度从列表 top 依次生成每个 entry 的目标 `minY`。总高度与初始列表一致。

- 非 source 行的 offset = `projectedMinY[id] - rowFrames[id].minY`（**这是唯一的“让位”机制**：邻行 spring 到 projected 位置，视觉上形成目标槽，但不改变 measured list height）。
- source overlay 的 settle Y = `projectedMinY[sourceId]`。
- cancel Y = `rowFrames[sourceId].minY`。
- `insertionIndicatorThickness = 2pt` 的**装饰性**目标槽指示器画在 overlay layer 槽位边界，不参与 measured list height；**不是**旧版 `insertionGap` 那种通过 `shift = rowHeight + spacing + 2pt` 物理撑开 VStack 的方案。它与 `targetHysteresis = 2pt` 是两个语义独立的常量。

邻行只对 derived offset 使用 `spring(response: 0.32, dampingFraction: 0.86)`；pointer 跟手位置不使用 spring。由于邻行 offset 和 overlay settle target 来自同一 projected geometry，drop 不可能再弹回 source 后跳序。

### D4 · pressing 不替换事件源

`InlineNotesTextView` 从 `mouseDown` 到对应 `mouseUp` 独占 gesture tracker。tracker 在 mouseDown 时快照 `reorderGestureEnabled`；SwiftUI 后续更新只能影响下一次手势，不能关闭正在进行的 tracking。

- timer 使用 common run-loop mode 或可注入 scheduler，保证按住鼠标期间 350ms 触发。
- 350ms 到达：session 进入 pressing，只给原行增加轻微 scale/shadow；原 `NSTextView` 继续挂载、可命中且不变为 placeholder。
- 累计移动达到 4pt：冻结槽位，创建轻量 drag preview，原行才变成保持布局的透明 placeholder，进入 dragging。
- 长按 350ms 后未达 4pt 即松手：清 pressing、回 idle、**不进入编辑**；仅 350ms 前释放的 quick click 进入编辑。

这避免现实现中“phase 变化 → placeholder 禁用 reorder → 下一次 mouseDragged 被自身拦截”的竞态。

### D5 · 有效区域、数据失效与 view teardown

dragging 的有效区域在 window 坐标中定义为“未完成列表 bounds 与可见 ScrollView viewport 的交集，再向四周扩展 `reorderExitTolerance = 12pt`”。pointer 位于真实 viewport 外但仍在 tolerance 内时继续手势，并把 viewport Y clamp 到最近边缘以保持 edge-scroll 速度；越过 tolerance 才进入 cancelling。

session 每次更新都比较当前 entries id sequence 与 `baseOrder`。若在 commit 前发生 identity 变化，则立即使 session generation 失效、停止 pointer/scroll 更新并取消持久化；仅当 source view 仍挂载时执行回源动画。`onDisappear` 在任何非 idle phase 都必须使 generation 失效、停止 scroll 和 pending completion，并清理 session，不允许 settling completion 在 view 消失后提交。

### D6 · 高频 pointer 与列表状态分离

session 分成两个发布边界：

- `TodayTodoDragPointerModel`：只发布浮层 Y，由叶子 `TodayTodoDragOverlay` 观察；parent list 不观察它。
- `TodayTodoReorderSession`：只在 phase、source 或 targetIndex 改变时发布，驱动邻行 offset。

drag preview 使用纯 SwiftUI、不可交互的轻量行外观，不实例化第二套 `TodayTodoInlineText`/`NSTextView`/Button。pointer 移动不得触发普通行的 `updateNSView`、text attributes 重写、intrinsic-size invalidation 或 row-frame Preference 更新。

备选的 CALayer 直接位移能进一步降低开销，但会增加 snapshot 与可访问性维护；首版采用叶子 ObservableObject 隔离，只在 Instruments/QA 仍显示掉帧时升级。

### D7 · 明确的落定、取消与无跳变 handoff

mouseUp 后停止接受 pointer 更新：

- `targetIndex == sourceIndex`：进入 cancelling，overlay spring 到 source Y，邻行 offset 回 0；完成后 reset，不写 store。
- index 改变：进入 settling，overlay spring 到 projected source Y，邻行保持 projected offset。

macOS 13 使用基于 `AnimatableModifier`/presentation value 的 completion observer；只有动画值到达目标才回调，不以 `response + 常数` 的固定 delay 代替完成语义。completion 必须幂等并绑定 session generation，防止旧回调提交新手势。

settling 完成后在同一个 `Transaction(animation: nil)` 中：

1. `store.reorderIncomplete(draggedId:toFinalIndex:)` 写入 `sortIndex`。
2. store 顺序切换为 `projectedOrder`。
3. session 清零、真实 source row 显示、overlay 移除。

旧 baseOrder + projected offsets 与新 store order + zero offsets 的屏幕位置相同，因此 handoff 没有瞬跳。持久化失败继续使用 `TodayTodoStore` 现有非阻塞错误语义；本 change 不扩展数据恢复策略。

### D8 · pinned edge scroll 使用两套明确坐标

插入计算只使用 content-local top-left Y；edge 判定只使用 viewport-local top-left Y。pointer bridge 同时从 `lastWindowPoint` 派生两者，禁止用 content Y 与 viewport height 比较。

`TodayTodoContentLayout` 暴露轻量 AppKit scroll bridge，按时间增量修改 `NSClipView` bounds origin（速度上限约 120pt/s），而不是反复 `ScrollViewProxy.scrollTo(first/last)`。每个 tick：

1. 根据 viewport Y 计算 edge velocity。
2. clamp 后滚动实际 delta。
3. 用同一 lastWindowPoint 重新换算 content Y。
4. 重算 targetIndex；冻结 row height/frame 的 content 坐标不变。

离开 edge、结束/取消拖拽、窗口消失时必须停止 tick source。compact 或不可滚动列表不启动 bridge。

### D9 · 测试以状态转移和可观察运动为准

测试不再以源码 contains 或“存在 spring 常量”作为动画成立证据。

- 纯状态：排除 source 的 targetIndex、连续跨槽、反向跨槽、hysteresis、不同高度行、projected offsets 与 settle Y。
- 手势：可注入 clock 驱动 350ms；pressing 后 SwiftUI sync 不得中断同一 mouse tracking；quick click 编辑、long-press/no-drag 不编辑、4pt 后 reorder 分流；越过有效区域取消。
- 发布边界：pointer 每像素更新只触发 pointer model；session/list objectWillChange 次数仅随 target/phase 改变。
- commit：settling completion 前零持久化；completion 后按 id/final index 写一次；Esc、有效区域退出、identity 变化和 view teardown 均不得写。
- scroll：contentY/viewportY 分离、实际 delta、边缘停止与滚动后 target 重算。
- Manual QA：抓起、跟手、逐槽让位、反向、落定、Esc、不同高度行、compact/pinned、边滚边拖和重新启动后的持久化均为完成硬门槛。

## Risks / Trade-offs

- **[Risk] 轻量 preview 与真实 AppKit 行外观有细微差异** → 共用 typography/layout tokens，并对单行、多行和 rollover hint 做截图 QA；不要在 overlay 中重新挂载 NSTextView。
- **[Risk] Animatable completion 可能重复或在 view teardown 时丢失** → 使用 session generation + 幂等 completion；onDisappear 走明确 cancel，不提交。
- **[Risk] 外部数据在拖动期间变化使 baseOrder 失效** → dragging/settling 时禁用该列表的完成、删除、编辑入口；检测 entries identity 改变则 cancel 回源，不以旧索引提交。
- **[Risk] AppKit incremental scroll 与 SwiftUI ScrollView 生命周期耦合** → bridge 弱引用 enclosingScrollView，tick 前验证 window/superview；失效时停止并保持当前 target。
- **[Trade-off] 不在拖动中物理换 ForEach 顺序** → accessibility order 在 drop 前保持原顺序，但视觉位置稳定且事件 identity 不会被重建；commit 后立即成为最终顺序。

## Migration Plan

1. apply 前在当前 checkout 创建 checkpoint commit，排除与本 change 无关的用户改动。
2. 先为现有实现补充必然失败的连续跨槽、pressing 事件连续性、非零 projected offset、目标 settle 和 pointer 发布边界测试。
3. 原位替换 controller/list/inline event bridge；删除 `previewOrder` 驱动、固定 settling delay、重复 `scrollTo` timer 与 drag overlay 中的 AppKit 行。
4. 以无动画 handoff 接入按 id/final index 的 store API，再跑聚焦测试与全量 build。
5. 完成 Manual QA 后更新集成文档；先完成并归档 `add-learning-today-todo`，再归档本 change。旧两个 reorder change 不归档，待用户确认后删除或标记为历史 superseded artifacts。

回滚只需回到 apply 前 checkpoint；不涉及 JSON migration。若新实现未通过 Manual QA，不允许以旧实现作为运行时 fallback。

## Open Questions

无。基础 capability 的归档顺序已经固定；旧 reorder change 目录的最终清理由用户在本 change 验收后决定，不阻塞实现。
