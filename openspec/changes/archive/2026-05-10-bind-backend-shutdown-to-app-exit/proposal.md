## Why

Cmd+Q exits the MalDaze frontend, but the learning-assistant backend lifecycle should be tied to the app-owned child process, not inferred later from a port scan. The current behavior can leave stale local services behind, and a port/PID-matching cleanup strategy would be too broad for normal desktop-app lifecycle management.

## Affected Specs

- `daily-morning-agent`

## What Changes

- Bind the app-spawned learning-assistant backend lifecycle to the MalDaze app lifecycle using explicit parent-child ownership.
- Make the backend self-terminate when its MalDaze parent process disappears, covering abnormal app exits where `applicationWillTerminate` may not run.
- Keep port probing limited to readiness/external-service detection; do not use port listeners as the source of ownership.
- Preserve the existing protection against killing manually launched or unrelated services on port `8765`.
- Add regression coverage for owned child shutdown, parent-loss shutdown, and external-backend preservation.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `daily-morning-agent`: clarify backend process ownership and shutdown behavior for the Swift-spawned local FastAPI backend.

## Impact

- Swift frontend lifecycle code:
  - `MalDaze/LearningAssistant/BackendProcessManager.swift`
  - `MalDaze/MalDazeAppDelegate.swift`
- Backend process bootstrap/lifespan code:
  - `assistant_backend/src/main.py`
- Swift and backend tests around explicit process ownership and parent-loss shutdown.
- No backend API changes.
- No database schema changes.
