## Context

- Dashboard 为 `DeskPetDashboardWindow` + `NSHostingController<DeskPetDashboardView>`；hide 用 `orderOut`，host 保留。
- `hideDashboardWindow()` 当前不通知 SwiftUI lifecycle；`LearningDeskFocusTimelineRow.onDisappear` 可能不触发。
- 多个 consumers 在 panel `onAppear` 启动 periodic / watcher 工作：
  - `FocusTimelinePresenter`（Change 1 后仍可能在错误 visible hint 下 live）
  - `LearningDeskPanelViewModel.startWatching()`（FSEvents）
  - `NutritionTodayViewModel.startWatching()`（FSEvents ×2）
- `deskPetDashboardDidOpen` 已存在；无 `DidClose`。

## Goals / Non-Goals

**Goals:**

- `NSWindow.isVisible == false`（orderOut 后）→ **零** Dashboard 域 repeating timer / live publish。
- 单一 phase SSOT；新 periodic consumer 必须 register。
- 保留 hide 后 UI 状态（scroll、tab、draft）— quiesce **work**，不 destroy **state**。

**Non-Goals:**

- 修改 Presenter 三态状态机（Change 1）。
- 销毁 `deskMenuHostingController` on hide。
- 收窄 `@ObservedObject AppViewModel`（Change 5）。
- Instruments signpost 基础设施（Change 6）。

## Decisions

### D1: Phase 权威在 WindowManager

```text
enum DashboardPresentationPhase {
    case absent    // 未创建 window/host
    case hidden    // orderOut，host 保留
    case visible   // isVisible
}
```

迁移点 **仅** `showDashboardWindow` / `hideDashboardWindow` / 首次 `makeDeskMenuWindowIfNeeded`（创建后 `.hidden` 直至 show）。

**Alternative rejected:** 仅靠 SwiftUI `onDisappear`——与 AppKit orderOut 语义不匹配（diag 已证）。

### D2: DashboardQuiescenceCoordinator

```text
protocol DashboardQuiescentConsumer {
    func dashboardDidHide()
    func dashboardDidShow()  // 可选 no-op；watcher 仍 onAppear 启动
}
```

- `AppViewModel` 持有 coordinator；consumers register at init。
- `pause()`：`dashboardDidHide()` on each。
- `resume()`：phase visible；**不** 自动 start 全部 watcher——panel `onAppear` 负责 lazy resume，避免 hidden 期间误触。

**Alternative rejected:** 每个 consumer 订阅 NotificationCenter 各自 pause——易遗漏，无 registry 审计。

### D3: FocusTimeline 集成

- hide → `focusTimelinePresenter.enterHidden()`（Change 1 API）
- show → `setConsumerVisible(true)` **仅当** today timeline row 应可见（coordinator + row hint 交集，初版：hide 强制 false；show 不自动 true，等 onAppear）

**Rationale:** show 时不盲目 `setVisible(true)`，避免用户上次在 schedule tab 却误启 timeline。

### D4: Watcher 集成

- hide → `learningDeskPanelViewModel.stopWatching()`、`nutritionViewModel.stopWatching()`（若曾 start）
- show → 不 eager start；`LearningDeskPanelView.onAppear` / nutrition panel onAppear 照旧

### D5: deskPetDashboardDidClose 通知

- post from `hideDashboardWindow` after phase migration
- 供非 WindowManager 路径或 future consumers 对齐（Today Todo 等）

### D6: 与 dashboard-standard-window 对齐

- State preservation on hide **不变**——quiescence 停止 **CPU work**，不清 `@State` / `@AppStorage`。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| show 后 watcher 未恢复 | onAppear 仍 startWatching；QA 关→开 Dashboard |
| 遗漏 register 的新 consumer | spec 要求 register；Change 6 源码测试 |
| coordinator 与 SwiftUI hint 双源冲突 | hide 时 AppKit 权威强制 pause；show 时 hint 恢复 |

## Migration Plan

1. Change 1 merged。
2. 实现 phase + coordinator + WindowManager hooks。
3. Register 3 consumers。
4. Failing tests + QA Release 10 min idle。
5. 无 user data migration。

## Open Questions

- Coordinator 独立 type vs `AppViewModel` extension——倾向 **独立 small type** 在 `MalDaze/DashboardQuiescence/`，AppViewModel 注入，便于单测。
