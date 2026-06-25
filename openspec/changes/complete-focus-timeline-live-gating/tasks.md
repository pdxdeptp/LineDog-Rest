## 0. Evidence baseline

- [x] 0.1 记录 `evidence/cpu-diag-baseline.md`：6/16–6/22 diag 摘要、栈、`autoWatching` 复现步骤
- [ ] 0.2 Release 构建 before 截图或 CPU 时间斜率（可选，与 Change 2 共用）

## 1. Failing tests (RED)

- [x] 1.1 `testVisibleAutoWatchingDoesNotStartLiveTick`
- [x] 1.2 `testVisibleAutoWatchingLiveTickDoesNotPublishDisplayModel`（generation / publish 计数 hook）
- [x] 1.3 `testManualWorkVisibleStartsLiveTickAndUpdatesOverlay`
- [x] 1.4 `testManualWorkEndsStopsTickAndClearsOverlayOnce`
- [x] 1.5 `testHiddenStopsTickAndClearsOverlay`
- [x] 1.6 扩展 `testLiveOverlayRefreshDoesNotRebuildSkeleton` 覆盖 live 态

## 2. Presenter state machine

- [x] 2.1 定义 internal scheduling phase（hidden | idle | live）与 `@testable isLiveTickActive`
- [x] 2.2 实现 `refreshLiveScheduling()` 唯一 timer 入口
- [x] 2.3 `setConsumerVisible(_:)`；`setVisible` 转发
- [x] 2.4 `enterHidden()` 供 Change 2 coordinator 调用
- [x] 2.5 删除 `setVisible(true)` 无条件 `startLiveTickIfNeeded()`
- [x] 2.6 修复 `syncLiveOverlay`：非 live 不 periodic publish；live 退出一次性清 overlay
- [x] 2.7 4 Hz repeating → 1 Hz one-shot chain（仅 live）

## 3. AppViewModel wiring

- [x] 3.1 `handleFocusPhaseEvent` / mode 切换 / start·abandon manual focus → `refreshLiveScheduling()`
- [x] 3.2 拆分 `refreshFocusSessionProjection`：非 session 变更不 rebuild skeleton
- [x] 3.3 确认 `handleTimeState` 仍不驱动 timeline

## 4. Validation

- [x] 4.1 `FocusTimelinePresenterTests` 全绿
- [ ] 4.2 `openspec validate complete-focus-timeline-live-gating`
- [ ] 4.3 Manual QA：autoWatching + Dashboard 今日 Tab 可见 ≥5 min 无 sustained 高 CPU
- [ ] 4.4 Manual QA：manual 专注 + 时间轴 visible，in-progress ≤1 Hz 更新；skip-rest / finalize 无 crash

## 5. Handoff to Change 2

- [x] 5.1 文档化 `enterHidden` / `setConsumerVisible` public surface（design D5）
- [x] 5.2 确认无 scattered `setVisible(false)` 依赖作为唯一 hide 机制
