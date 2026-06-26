## 1. Coordinator symmetric lifecycle

- [x] 1.1 RED: extend `DashboardQuiescenceCoordinatorTests` — `hidden→visible` invokes resume handlers; `visible→hidden` invokes pause; paired registration
- [x] 1.2 Implement `registerConsumer(pause:resume:)` (or equivalent paired API) and `resumeAll()` on `transition(to: .visible)` from `.hidden` / `.absent`
- [x] 1.3 GREEN: coordinator unit tests pass

## 2. AppViewModel composition root

- [x] 2.1 Move `NutritionTodayViewModel` and `LearningDeskPanelViewModel` ownership to `AppViewModel` (shared instances)
- [x] 2.2 Register three consumers at `AppViewModel` init: FocusTimeline pause/resume (resume no-op for live visibility), nutrition pause/resume, learning pause/resume
- [x] 2.3 Verify `dashboardPresentationDidShow()` / `DidHide()` paths call `transition` that triggers pause/resume (no extra WindowManager hooks)

## 3. Panel view decoupling

- [x] 3.1 `NutritionTodayPanelView`: inject `@ObservedObject` VM from parent; remove `deskPetDashboardDidClose` watcher stop; remove `onAppear`/`onDisappear` `startWatching`/`stopWatching`
- [x] 3.2 `LearningDeskPanelView`: inject `@ObservedObject` VM; remove `deskPetDashboardDidClose` watcher stop and `enterTimelineHidden` duplicate; remove `onAppear`/`onDisappear` watcher lifecycle
- [x] 3.3 `DashboardRootView`: pass AppViewModel-owned VMs into nutrition/learning panels
- [x] 3.4 Source test: panel views must not contain `deskPetDashboardDidClose` + `stopWatching` or `onAppear` + `startWatching`

## 4. Resume catch-up behavior

- [x] 4.1 `NutritionTodayViewModel`: expose/document resume entry (`startWatching` + `loadToday(showLoading: false)`); ensure idempotent `startWatching`
- [x] 4.2 `LearningDeskPanelViewModel`: resume entry (`startWatching` + catch-up load); avoid blocking show path
- [x] 4.3 RED→GREEN: `NutritionTodayViewModelTests` — after pause/resume simulation, disk change triggers refresh

## 5. Validation

- [x] 5.1 `openspec validate complete-dashboard-quiescence-resume`
- [x] 5.2 Run focused tests: `DashboardQuiescenceCoordinatorTests`, `NutritionTodayViewModelTests`, `EnergyWakeupSourceTests`
- [ ] 5.3 Manual QA: open Dashboard → hide → show → Hermes log food → nutrition consumed updates within ~2s without manual refresh button
- [ ] 5.4 Manual QA: repeat for learning projects file change; confirm hidden Dashboard idle still low CPU (quiescence 5.2 regression)
- [x] 5.5 Update `docs/integrations/features/nutrition-today-panel.md` FSEvents lifecycle sentence (coordinator SSOT, not onAppear)

## 6. Close quiescence change loop

- [x] 6.1 Mark `add-dashboard-presentation-quiescence` tasks 1.3 / 5.3 / 5.4 complete after this change lands
- [ ] 6.2 Archive pairing per team process when M1 evidence collected
