## Context

- **现状**：`LearningDeskPanelView.focusTimelineRow` 在 SwiftUI `body` 求值时调用 `FocusDayTimelineCellGridModel.make(now:…)`，输入来自 `@ObservedObject appViewModel` 的 `todayFocusSessions` / `inProgressFocusSegment`。
- **刷新源**：手动专注时 `ManualTimerEngine` 约 1Hz 触发 `AppViewModel.handleTimeState` → `publishStatus` + `refreshFocusSessionProjection()`，导致 **整棵 learning panel** invalidation。
- **崩溃**：`appendMappedSuccess` 用 `DateInterval(start: sessionStartedAt, end: sessionEndedAt)`；`skipRestPhaseToWork()` 将 `workPhaseStart` 设为 **未来 rest 结束时刻**，使 `startedAt > min(now, endsAt)`，Foundation trap（DiagnosticReports 2026-06-20 19:20/19:21，栈一致）。
- **约束**：`focus-sessions.json` 仍为 SSOT；Hermes 只读；不改变 P1 时间轴视觉规则（`redesign-focus-day-timeline-grid` / `refactor-manual-focus-coordinator` 已定稿的格子、marker、popover）。

## Goals / Non-Goals

**Goals:**

- 时间轴 **结构布局** 仅在 session 事件时重算（append / delete / edit / 跨日）。
- **进行中条** 以 ≤1Hz、**仅面板可见** 的方式更新 live overlay，不重建整日网格。
- 消除 `startedAt > now` 的「运行中工作段」；网格构建路径对区间输入 **永不 trap**（语义正确优先，其次防御）。
- 学习面板 **不订阅** `AppViewModel.statusLine` 等与时间轴无关的 tick。

**Non-Goals:**

- 历史日浏览、导出、streak。
- 重写 `FocusSessionStore` 或 Hermes 写入。
- Dashboard 右栏恢复专注列表（仍移除状态）。
- Canvas/Metal 级渲染优化（SwiftUI 子树 + 缓存足够）。

## Decisions

### D1: 提前结束休息 → 下一工作段从 **now** 开始

- **Decision**: `ManualTimerEngine.skipRestPhaseToWork()` 使用 `let nextStart = Date()`（与 `tick()` 自然结束休息一致），不再使用 rest 的 `phaseEnd` 作为未来起点。
- **Rationale**: 「运行中」在产品和投影里意味着 `startedAt ≤ now ≤ endsAt`；时间轴、popover、`FocusPomodoroInProgress` 均依赖该不变量。
- **Alternative rejected**: 保留未来起点 + 时间轴 clamp —— 掩盖语义，仍浪费算力，且与「已 X 分钟」文案矛盾。

### D2: 引入 `FocusTimelinePresenter`（MainActor）

- **Decision**: Presenter 持有：
  - `daySkeleton: FocusDayTimelineDaySkeleton` —— 无 in-progress 的格子网格（completed fill + failed markers + visible window）。
  - `liveOverlay: FocusTimelineLiveOverlay?` —— 仅当前 manual work phase 的 `{ displayStart, displayEnd, remainingSeconds, … }`。
  - `displayModel` —— skeleton ⊕ overlay 的 **只读** 合并结果，供 `FocusDayTimelineCellGridView` 使用。
- **重建规则**:
  - `rebuildSkeleton()`：`FocusSessionStore` today finalized 变化、timeline day 变化、编辑/删除回调。
  - `refreshLiveOverlay(now:)`：manual work running 且 **consumer visible**；否则 `liveOverlay = nil`。
- **Rationale**: 纯函数 `make()` 保留给单测与 skeleton 构建；live 路径 O(1) 更新当前 phase 相交格，而非 O(cells×sessions)。

### D3: 可见性门控 live tick

- **Decision**: `LearningDeskPanelView` 在 `onAppear`/`onDisappear`（或 Today tab 可见性）通知 presenter `setVisible(_:)`。仅 `visible == true` 且 manual work active 时，presenter 用 `TimelineView(.periodic)` **或** 单一 `Timer`/engine 整秒回调刷新 overlay。
- **Rationale**: 面板关闭时不应每秒做 focus 几何；与 `LearningDeskPanelViewModel.stopWatching()` 对称。
- **Alternative rejected**: 全局 AppViewModel 1Hz 广播 —— 当前问题根源。

### D4: 窄 observation —— 学习面板不绑整个 `AppViewModel` 做时间轴

- **Decision**: 时间轴子树使用 `@ObservedObject var focusTimeline: FocusTimelinePresenter`（或 `@StateObject` 由 Dashboard 注入）。Presenter 通过 **显式** `handleFocusStoreChanged()` / coordinator 回调 / engine phase 事件更新，**不**因 `statusLine` 变化而 `@Published`。
- **Rationale**: 切断菜单栏倒计时与学习网格的刷新耦合。
- **Note**: `AppViewModel` 可保留 `inProgressFocusSegment` 供其它面（若有）；时间轴 presenter 从同一 coordinator 读，但不与 VM 每 tick 同频 `@Published`。

### D5: 网格构建 API 拆分

- **Decision**:
  - `FocusDayTimelineCellGridModel.makeSkeleton(… finalizedSessions …)` —— 不含 in-progress；不依赖 `now`。
  - `FocusDayTimelineCellGridModel.applying(liveOverlay:to:)` —— 合并进行中 fill；要求 `overlay.displayStart ≤ overlay.displayEnd`；若违反则 **omit overlay** 并 `assertionFailure` in DEBUG，RELEASE 跳过（不应再发生 after D1）。
- **Rationale**: 单测可固定 skeleton；live 路径可单独测 fraction 变化。
- **Alternative rejected**: 在 `appendMappedSuccess` 加 clamp —— 用户明确拒绝「打补丁」式修复。

### D6: `refreshFocusSessionProjection` 职责收缩

- **Decision**: `AppViewModel.refreshFocusSessionProjection` 仍更新 Dashboard 需要的 summary 字段，但 **移除** 在 `handleTimeState(.working)` 内对「仅时间轴 live 所需字段」的每 tick 写入；改为 presenter 在 visible 时自行读 coordinator projection。
- **Rationale**: 减少全局 `@Published` churn；summary `N/X` 在 finalize 时变，不需每秒变（进行中分钟可只在 presenter overlay 文案显示，或 summary 仅 completed 分钟——与现有 `todayCompletedMinutes` 一致）。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| Presenter 与 AppViewModel 双读 coordinator 漂移 | 同一 `ManualFocusCoordinator` + 单元测试 assert projection 一致 |
| 可见性边界（切 tab 未 disappear） | Today tab 选中态也门控 `setVisible` |
| skeleton/live 合并 bug | 保留 `FocusDayTimelineCellGridModelTests` + 新 presenter 测试 |
| 跳过休息语义变更 | 单测更新 `ManualTimerEnginePhaseReplayTests`；用户可见行为：跳休息后立即进入工作倒计时 |

## Migration Plan

1. 实现 presenter + skeleton/live API；视图切 presenter 输入。
2. 修正 `skipRestPhaseToWork` 起点；补 skip-rest + timeline 集成测试。
3. 从 `handleTimeState` 移除每 tick 的 timeline 驱动；验证 DiagnosticReports 场景不再复现。
4. 无 JSON migration；无 Hermes 变更。

## Open Questions

- None blocking：presenter 生命周期由 Dashboard 注入单例 vs 每 panel `@StateObject`——倾向 **AppViewModel 持有 presenter 实例**，学习面板只观察 presenter（与 focus store 同寿命）。
