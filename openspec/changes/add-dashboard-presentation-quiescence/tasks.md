## 0. Prerequisite

- [x] 0.1 `complete-focus-timeline-live-gating` merged；Presenter 暴露 `enterHidden` / `setConsumerVisible`

## 1. Core infrastructure

- [x] 1.1 添加 `DashboardPresentationPhase` enum
- [x] 1.2 实现 `DashboardQuiescenceCoordinator`（register / pause / resume）
- [ ] 1.3 `DashboardQuiescentConsumer` protocol
- [x] 1.4 `AppViewModel` 持有 coordinator；init 时 register consumers

## 2. WindowManager integration

- [x] 2.1 `hideDashboardWindow` → phase `.hidden` → `coordinator.pause()`
- [x] 2.2 `showDashboardWindow` → phase `.visible` → `coordinator.resume()`
- [ ] 2.3 首次 `makeDeskMenuWindowIfNeeded` 创建后 phase `.hidden` 直至 show
- [x] 2.4 添加 `MalDazeBroadcastNotifications.deskPetDashboardDidClose`；hide 时 post

## 3. Consumer adapters

- [x] 3.1 `FocusTimelinePresenter`: `dashboardDidHide` → `enterHidden()`
- [x] 3.2 `LearningDeskPanelViewModel`: `dashboardDidHide` → `stopWatching()`
- [x] 3.3 `NutritionTodayViewModel`: `dashboardDidHide` → `stopWatching()`
- [x] 3.4 保留 SwiftUI `onAppear`/`onDisappear` 作 hint；文档标明非 SSOT

## 4. Tests

- [x] 4.1 `DashboardQuiescenceTests`: phase hidden → consumers paused
- [x] 4.2 源码测试：`hideDashboardWindow` 调用 pause / `enterHidden`
- [ ] 4.3 集成：hide 后 `@testable isLiveTickActive == false`（Presenter）

## 5. Validation

- [x] 5.1 `openspec validate add-dashboard-presentation-quiescence`
- [ ] 5.2 Manual QA Release：开 Dashboard 今日 Tab → 关 → 后台 idle **10 min**，无 ~50% CPU / 新 diag
- [ ] 5.3 Manual QA：关→开 Dashboard，learning/nutrition 数据仍可通过 refresh/onAppear 加载
- [ ] 5.4 填写 `evidence/after-quiescence-idle-10min.md`

## 6. Archive milestone M1

- [ ] 6.1 archive `complete-focus-timeline-live-gating` + `add-dashboard-presentation-quiescence`（按团队流程）
