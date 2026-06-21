## 1. Engine phase events

- [x] 1.1 Add `ManualPhaseEvent` enum and `onPhaseEvent` callback to `ManualTimerEngine`
- [x] 1.2 Emit events from `tick()`, `start()`, `skipRestPhaseToWork()`, and `emit()`
- [x] 1.3 Refactor `reconcileWallClockFromPersisted` to emit work-completed/rest transitions per loop iteration
- [x] 1.4 Expose `currentWorkPhase` read model (`startedAt`, `endsAt`, `remaining`)
- [x] 1.5 Add `ManualTimerEnginePhaseReplayTests` (relaunch catch-up, skip-rest; no pause cases)

## 2. ManualFocusCoordinator

- [x] 2.1 Create `ManualFocusCoordinator` with `handle(event:)`, `abandonCurrentWorkPhase(now:)`, `projection(now:)` — **no pause API**
- [x] 2.2 Forest rules: complete on workCompleted, stoppedEarly on abandon; rest clears in-progress
- [x] 2.3 Add `FocusPomodoroInProgress`; remove wall-clock session anchor
- [x] 2.4 Add `ManualFocusCoordinatorTests` (replay completions, abandon scope, no pause JSON)

## 3. Remove pause/resume

- [x] 3.1 Delete `stopTimers`, `resumeTimers`, `chronoSessionSuspendedByUser`, `showResumeChronoButton` from `AppViewModel`
- [x] 3.2 Remove `persistUserPaused`, `restoreUserPaused`, `restoreUserPausedModeOnly`, `PauseKind.user`, mode-only suspend from chrono layer
- [x] 3.3 Remove Dashboard「停止计时 / 恢复计时」; add manual **放弃当前番茄**; auto **停止自动提醒**
- [x] 3.4 Migration: clear legacy `suspendedTimerModeSnapshot` and user-paused envelopes on load
- [x] 3.5 Update/remove tests: `ChronoSessionCoordinatorTests`, `MalDazeInteractionTests`, `ControlPanelPresentationTests`

## 4. AppViewModel + chrono v3 integration

- [x] 4.1 Wire engine events → coordinator; remove `workSegmentStartedAt`, `wasInManualWorkPhase`, begin/finalize helpers
- [x] 4.2 `startManualFocus` / `setMode` / new `abandonManualFocus()` call coordinator
- [x] 4.3 Running-only chrono capture on terminate/resign-active; v3 schema without `workSegmentStartedAt` or user pause
- [x] 4.4 Publish focus fields from `coordinator.projection(now:)` only

## 5. Timeline and popover UI

- [x] 5.1 Grid model consumes capped `FocusPomodoroInProgress`
- [x] 5.2 In-progress popover: 本颗番茄 · 已 X / 共 Y · 剩余 Z
- [x] 5.3 Remove paused-state timeline assumptions; update tests
- [x] 5.4 Presentation tests: no stop/resume strings; abandon button present during manual work

## 6. Validation

- [x] 6.1 Run coordinator, engine replay, chrono, timeline, interaction, presentation tests
- [ ] 6.2 Manual QA: start → abandon (枯树) → start new; complete → rest; relaunch while running replays completed; no resume UI
- [x] 6.3 `openspec validate refactor-manual-focus-coordinator`
