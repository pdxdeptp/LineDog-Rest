## 1. Suspended Timer Regression Coverage

- [x] 1.1 Add a failing Swift regression test proving an auto-mode "停止计时" snapshot survives a bootstrapped `AppViewModel` restart with no timer running, "恢复计时" visible, and paused pet state.
- [x] 1.2 Add a failing Swift regression test proving a manual-mode stopped snapshot restores manual mode on bootstrapped restart and `resumeTimers()` restarts the manual engine.
- [x] 1.3 Add a failing Swift regression test proving invalid persisted stopped-state values are cleared and default auto bootstrap behavior still runs.

## 2. Persistence Implementation

- [x] 2.1 Add a `MalDazeDefaults` key for the suspended timer mode snapshot.
- [x] 2.2 Update `AppViewModel` launch initialization to restore a valid suspended snapshot before deciding whether to start `AutoTimerEngine`.
- [x] 2.3 Persist the current mode when `stopTimers()` transitions an active session into user-stopped state.
- [x] 2.4 Clear the suspended snapshot when `resumeTimers()`, `startManualFocus()`, or `setMode(_:)` ends the stopped-session meaning.

## 3. Verification

- [x] 3.1 Run focused Swift tests for timer interactions.
- [x] 3.2 Run OpenSpec validation/status for `persist-suspended-timer-state`.
- [x] 3.3 Manually verify in the running app: stop计时, quit/relaunch, confirm pet remains paused and "恢复计时" is available.
