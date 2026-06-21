## 1. Engine time semantics

- [x] 1.1 Change `ManualTimerEngine.skipRestPhaseToWork()` to start next work at `Date()` (match natural `tick()` transition)
- [x] 1.2 Update `ManualTimerEnginePhaseReplayTests` for skip-rest start-at-now invariant

## 2. Grid model API split

- [x] 2.1 Add `makeSkeleton(finalizedSessions:timelineDay:calendar:)` without `now` / in-progress
- [x] 2.2 Add `applying(liveOverlay:to:)` merge path; DEBUG assert / RELEASE omit on invalid interval
- [x] 2.3 Refactor existing `make()` to compose skeleton + overlay (or deprecate direct body use)
- [x] 2.4 Extend `FocusDayTimelineCellGridModelTests` for skeleton-only and overlay merge

## 3. FocusTimelinePresenter

- [x] 3.1 Create `FocusTimelinePresenter` with skeleton cache, live overlay, `displayModel`, `setVisible(_:)`
- [x] 3.2 Rebuild skeleton on finalize / delete / edit / day change via coordinator + store callbacks
- [x] 3.3 Refresh live overlay at most 1Hz while visible + manual work active; clear overlay when hidden or resting
- [x] 3.4 Add `FocusTimelinePresenterTests` (no rebuild on tick, visible gating, skip-rest invariant)

## 4. AppViewModel decoupling

- [x] 4.1 Hold presenter on `AppViewModel`; wire phase/session events to `rebuildSkeleton` / overlay refresh
- [x] 4.2 Remove per-tick `refreshFocusSessionProjection()` from `handleTimeState(.working)` when only countdown changed
- [x] 4.3 Keep summary fields updated on finalize events; document/live overlay owns in-progress minute display on grid

## 5. Learning desk panel integration

- [x] 5.1 Replace body内 `FocusDayTimelineCellGridModel.make()` with presenter `displayModel`
- [x] 5.2 Gate `setVisible(true/false)` on panel appear/disappear and today-tab visibility
- [x] 5.3 Stop observing whole `AppViewModel` for timeline subtree where possible (presenter-only)
- [x] 5.4 Update `ControlPanelPresentationTests` (no `make()` in `focusTimelineRow` body; presenter wiring)

## 6. Validation

- [x] 6.1 Run presenter, grid model, engine replay, interaction, presentation tests
- [x] 6.2 Manual QA: open today header during focus — no crash after skip-rest; CPU stable; skeleton stable while countdown ticks
- [x] 6.3 `openspec validate refactor-focus-timeline-presenter`
