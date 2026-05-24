## Why

Users can stop the active timer and see a resume action during the current app session, but that stopped state is currently kept only in memory. Restarting MalDaze starts from the default auto-running timer state, so a user-intended pause is lost across launches.

## What Changes

- Persist the user-stopped timer session state, including the suspended timer mode, when the user chooses "停止计时".
- Restore the stopped state on app launch so the app stays paused in the suspended mode and continues to show "恢复计时" instead of auto-starting the timer.
- Clear the persisted stopped state when the user resumes timers, starts a new manual focus session, or switches timer mode.
- Keep this limited to the desk-pet timer controls; no backend, reminder, or learning assistant behavior changes.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `desk-pet-controls`: timer controls must preserve a user-stopped timer session across app restarts.

## Impact

- Affected code: `MalDaze/AppViewModel.swift`, `MalDaze/MalDazeDefaults.swift`.
- Affected tests: `MalDazeTests/MalDazeInteractionTests.swift` or focused timer control tests.
- Data storage: add one small `UserDefaults` key for the persisted suspended timer mode snapshot.
