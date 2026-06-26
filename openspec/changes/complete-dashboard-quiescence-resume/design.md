## Context

- Dashboard：`DeskPetDashboardWindow` + 长生命周期 `NSHostingController<DeskPetDashboardView>`；hide = `orderOut`，不 destroy host。
- `add-dashboard-presentation-quiescence` 已 land：`DashboardPresentationPhase`、`deskPetDashboardDidClose`、`dashboardPresentationDidHide/Show()` → `coordinator.transition`。
- **缺陷**：
  1. `DashboardQuiescenceCoordinator` 仅 `registerPauseHandler` + `pauseAll()`；`transition(to: .visible)` 无 `resumeAll()`。
  2. 原 proposal 要求 register `NutritionTodayViewModel` / `LearningDeskPanelViewModel`，实际只在 View 里订阅 `DidClose`——违反 D2「单一 registry、拒绝 NotificationCenter 各自 pause」。
  3. 原 design D4「show → 不 eager start；靠 onAppear」与 orderOut 语义冲突——**这是根因设计错误**，须在本 change 修正，而非在 `NutritionTodayPanelView` 加 `DidOpen` 补丁。
- 饮食/学习 ViewModel 当前为 Panel 内 `@StateObject`，AppViewModel 无法在 init 注册——须调整 ownership 才能满足原 proposal。

## Goals / Non-Goals

**Goals:**

- Dashboard phase `.hidden` ↔ `.visible` 对 **file watcher consumers** 对称 pause/resume；AppKit phase 为唯一权威。
- Coordinator registry 覆盖：`FocusTimelinePresenter`（pause-only forced hidden）、`NutritionTodayViewModel`、`LearningDeskPanelViewModel`。
- Show 后 Hermes 磁盘变更在 ≤1s debounce 内反映到 UI（与 `nutrition-today-panel` FSEvents requirement 一致）。
- Resume 时 catch-up 隐藏期间错过的写入（`loadToday` / learning 等价 refresh），不依赖 missed FSEvents。
- 保留 hide 后 UI state（scroll、tab、draft）；不 destroy host。

**Non-Goals:**

- 恢复 45s nutrition 轮询（已在 `df25d44` 移除；FSEvents + show catch-up 足够）。
- 修改 FocusTimeline 三态机或 tab-gated `setVisible(true)` 策略。
- 销毁 `deskMenuHostingController` on hide。
- 用 `deskPetDashboardDidOpen` 在单个 Panel 内 scattered `startWatching()`（拒绝 patch 模式）。

## Decisions

### D1: Coordinator 对称 API

```text
registerConsumer(
  id: String,           // 或 UUID，便于测试断言
  pause: () -> Void,
  resume: () -> Void
)

transition(to:):
  .visible when old == .hidden  → resumeAll()
  .hidden  when old == .visible → pauseAll()
  .visible when old == .absent  → resumeAll()   // 首次 show
  .absent / no-op combinations  → 不 double-resume
```

**Rationale:** 原 proposal 即 pause/resume pair；单腿 pause 是 incomplete implementation。

**Alternative rejected:** 仅在各 Panel 订阅 `deskPetDashboardDidOpen`——scattered、易遗漏、违反 quiescence SSOT。

### D2: 提升 Dashboard Hermes ViewModels 到 AppViewModel

```text
AppViewModel
  let nutritionToday = NutritionTodayViewModel()
  let learningDeskPanel = LearningDeskPanelViewModel()
  init → registerConsumer 三组 handler
```

Panel views 改为 `@ObservedObject var viewModel: …` 由 `DashboardRootView` / `LearningDeskPanelView` init 注入。

**Rationale:** 原 change proposal 明确「AppViewModel init 时 register consumers」；View 内 `@StateObject` 使 registry 不可能完整。

**Alternative rejected:** View `onAppear` 里 `coordinator.register`——生命周期与 host 创建顺序耦合，且 repeat register 需 guard，仍非 SSOT。

### D3: Consumer resume 语义（分类型）

| Consumer | pause | resume |
|----------|-------|--------|
| `NutritionTodayViewModel` | `stopWatching()` | `startWatching()` + `loadToday(showLoading: false)` |
| `LearningDeskPanelViewModel` | `stopWatching()` | `startWatching()` + 若已 load 则 `scheduleDebouncedRefresh` 或 `loadToday()` |
| `FocusTimelinePresenter` | `enterHidden()` | **no-op**（或仅 clear forced-hidden flag if added）；`setVisible(true)` 仍由 Today tab timeline row `onAppear` |

**Rationale:** File watcher 在 Dashboard visible 期间应始终活跃（nutrition 左栏、learning projects 全局）。Timeline live tick 仍 tab-gated，避免 schedule tab 误启 1 Hz tick（原 D3）。

### D4: 剥离 SwiftUI lifecycle 对 watcher 的权威

从 `NutritionTodayPanelView` / `LearningDeskPanelView` **删除**:

- `.onReceive(deskPetDashboardDidClose) { stopWatching }`
- `.onAppear { startWatching }` / `.onDisappear { stopWatching }`

保留（非 watcher 权威）:

- `onAppear { loadToday() }` 仅当首次 mount 需要且 resume 已 cover catch-up 时可省略；若保留须文档标注 **hint only**。
- `LearningDeskPanelEnvironment.enterTimelineHidden()` 不再从 `DidClose` 调用——coordinator pause handler 已 `enterHidden()`。

`deskPetDashboardDidClose` / `DidOpen` **保留** 给非 quiescence consumer（如 `TodayTodoSection` draft focus）。

### D5: WindowManager 不变更 dismiss 语义

`showDashboardWindow` / `hideDashboardWindow` 已调用 `dashboardPresentationDidShow/Hide()`；本 change 仅让 `transition(to: .visible)` 触发 `resumeAll()`。不在 WindowManager 直接调 ViewModel。

### D6: 测试策略

- Unit: `transition hidden→visible` 调用 resume handler；`visible→hidden` 调用 pause；成对注册顺序无关。
- Unit: `NutritionTodayViewModel` resume 后 `fileWatcher != nil`；mock reader 变更后 refresh。
- Source test: `NutritionTodayPanelView` / `LearningDeskPanelView` **不含** `deskPetDashboardDidClose` + `stopWatching`；**不含** `onAppear` + `startWatching`。
- Manual QA（继承 quiescence 5.3）：关→开 Dashboard → Hermes 记餐 → ≤2s UI 更新。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| AppViewModel 膨胀 | 仅提升已存在的两个 Dashboard VM；不迁 whole Dashboard state |
| resume 时 double load | `startWatching` idempotent；`loadToday(showLoading: false)` 轻量 |
| hidden 期间 Hermes 写入 missed FSEvents | resume catch-up read 磁盘 |
| FocusTimeline 与 coordinator 双源 | timeline 仅 pause-side 注册；resume no-op；tab onAppear 仍 gate live |

## Migration Plan

1. 扩展 coordinator API + tests（RED）。
2. 提升 VMs 到 AppViewModel + register consumers。
3. 改 Panel views 注入 + 删 scattered lifecycle。
4. `dashboardPresentationDidShow` path 验证 resume 调用链。
5. 更新 specs + manual QA 5.3 + `after-quiescence-idle-10min.md` functional row。
6. 无用户数据迁移。

## Open Questions

- `LearningDeskPanelViewModel` resume 是否应用 `loadToday(force:)` 还是仅 `poll`/debounced read——倾向 **resume 调 `loadToday()`**，与 nutrition 对称；schedule tab 不在前台时多一次 CLI 可接受，或可 gate 为「仅 today/schedule 已 load 时 refresh」。
