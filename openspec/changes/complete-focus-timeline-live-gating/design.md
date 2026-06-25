## Context

- `FocusTimelinePresenter` 持有 `day skeleton`（session 事件重建）与 `live overlay`（manual work 进行中条）。
- `LearningDeskFocusTimelineRow` 在 `onAppear` 调 `setVisible(true)`，`onDisappear` 调 `setVisible(false)`。
- `AppViewModel` 持有 presenter 实例；`liveInputProvider` 供 overlay 读 manual projection。
- diag 证据：autoWatching 时 `liveTick` 仍每秒 `syncLiveOverlay` → `publishDisplayModel(overlay: nil)` → `@Published` 通知（值同 skeleton 也触发）。

## Goals / Non-Goals

**Goals:**

- 实现与 `refactor-focus-timeline-presenter` design **D3** 一致的 live scheduling 语义。
- 消除 autoWatching + visible 时的 periodic `@Published` churn。
- manual work + visible 时保留 ≤1 Hz in-progress overlay 更新；skeleton generation 不变。
- 为 Change 2 暴露清晰的 consumer visibility API（`setConsumerVisible` / `enterHidden`）。

**Non-Goals:**

- Dashboard `orderOut` / quiescence registry（Change 2）。
- `@ObservedObject AppViewModel` 观察面收窄（Change 5）。
- `ManualTimerEngine` wake 频率（Change 3）。
- Equatable 短路作为主修复手段。

## Decisions

### D1: 三态状态机（hidden | idle | live）

| 状态 | 进入条件 | Timer | publish |
|------|----------|-------|---------|
| **hidden** | `!isConsumerVisible` | 无 | hidden 迁移时若曾有 overlay，**一次性**清 overlay |
| **idle** | visible，无 manual work active | 无 | 仅 skeleton 事件（finalize / edit / day change） |
| **live** | visible + manual work active + valid projection | 1 Hz one-shot chain | 仅 overlay 变化 |

**Rationale:** 将「可见」与「需要 live tick」解耦；`setVisible(true)` 只表示 consumer 可能在看，不自动进入 `live`。

**Alternative rejected:** 保留 4 Hz timer + `wholeSecond` 去重——仍 4×/s MainActor wake，且 autoWatching 仍 publish。

### D2: `refreshLiveScheduling()` 为唯一 timer 入口

所有迁移经此函数：`setConsumerVisible`、`syncLiveOverlay`（phase 边界）、manual mode 切换。

**Alternative rejected:** 在 `liveTick` 内 guard 后 return——timer 仍在跑，治标不治本。

### D3: 非 live 路径禁止 periodic publish

`syncLiveOverlay` 在 `!manualWorkActive` 时：
- 若当前 display 已无 in-progress overlay → **return，不 publish**
- 若刚从 live 退出 → **publish 一次**清 overlay

**Alternative rejected:** `@Published` Equatable 短路——掩盖错误调用路径。

### D4: 1 Hz one-shot chain（非 repeating）

对齐 `AutoTimerEngine.scheduleRestTick`：每次 tick 末尾 schedule 下一 whole second。

**Alternative rejected:** `TimelineView(.periodic)`——与 AppKit Dashboard host 生命周期耦合更复杂。

### D5: `setVisible` 重命名为/包装为 `setConsumerVisible`

保留 `setVisible` 作 SwiftUI 兼容别名；文档标明 **hint only**，Change 2 的 phase SSOT 可 override。

### D6: `refreshFocusSessionProjection` 拆分

- `rebuildSkeleton`：session / day 变更
- `refreshLiveScheduling`：phase 变更
- 移除「每次 projection refresh 都 `syncFocusTimelineSkeleton`」除非 session 数据变

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| manual 专注时 overlay 不更新 | phase event 显式 `refreshLiveScheduling`；单测 live 路径 |
| hidden 后 stale in-progress UI | hidden 迁移一次性清 overlay；Change 2 QA 关窗场景 |
| SwiftUI onAppear 与 phase 双源 | Change 2 统一；本 change 先保证逻辑正确 |

## Migration Plan

1. 写 failing 状态矩阵单测。
2. 实现状态机 + 删 periodic publish 路径。
3. 接 AppViewModel phase 边界。
4. Manual QA：autoWatching 开 Dashboard 无 sustained CPU。
5. 无 JSON / Hermes migration。

## Open Questions

- None blocking. `@testable` 暴露 `liveTickTimer != nil` 或 internal `schedulingPhase` 供单测——倾向 `@testable var isLiveTickActive`.
