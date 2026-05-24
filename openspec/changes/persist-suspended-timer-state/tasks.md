## 1. Suspended Timer Regression Coverage

- [ ] 1.1 Add a failing Swift regression test proving an auto-mode "停止计时" snapshot survives a bootstrapped `AppViewModel` restart with no timer running, "恢复计时" visible, and paused pet state.
- [ ] 1.2 Add a failing Swift regression test proving a manual-mode stopped snapshot restores manual mode on bootstrapped restart and `resumeTimers()` restarts the manual engine.
- [ ] 1.3 Add a failing Swift regression test proving invalid persisted stopped-state values are cleared and default auto bootstrap behavior still runs.

## 2. Persistence Implementation

- [ ] 2.1 Add a `MalDazeDefaults` key for the suspended timer mode snapshot.
- [ ] 2.2 Update `AppViewModel` launch initialization to restore a valid suspended snapshot before deciding whether to start `AutoTimerEngine`.
- [ ] 2.3 Persist the current mode when `stopTimers()` transitions an active session into user-stopped state.
- [ ] 2.4 Clear the suspended snapshot when `resumeTimers()`, `startManualFocus()`, or `setMode(_:)` ends the stopped-session meaning.

## 3. Verification

- [ ] 3.1 Run focused Swift tests for timer interactions.
- [ ] 3.2 Run OpenSpec validation/status for `persist-suspended-timer-state`.
- [ ] 3.3 Manually verify in the running app: stop计时, quit/relaunch, confirm pet remains paused and "恢复计时" is available.
