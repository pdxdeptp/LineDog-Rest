## 1. Test Scaffolding

- [x] 1.1 Re-read `BackendProcessManager.swift`, `MalDazeAppDelegate.swift`, `assistant_backend/src/main.py`, and the delta spec to confirm final write boundaries before dispatch.
- [x] 1.2 Add failing Swift tests for backend lifecycle decisions: app-spawned child terminates on app exit, externally occupied port is not terminated, and spawned backend receives parent identity in its environment.
- [x] 1.3 Add failing backend tests for parent monitor behavior: expected parent still present keeps running, parent mismatch requests graceful shutdown, and no parent identity disables the monitor.
- [x] 1.4 Add or update tests proving `applicationWillTerminate` still invokes backend shutdown before other app lifecycle cleanup completes.

## 2. Explicit Child Lifecycle Implementation

- [x] 2.1 Add small internal Swift test seams for process creation, environment construction, and process termination without relying on real uvicorn processes in unit tests.
- [x] 2.2 Update `BackendProcessManager` spawn logic to pass `MALDAZE_PARENT_PID` as an internal-only backend control environment variable for app-owned child processes; do not expose it as user configuration or require it for manual backend launches.
- [x] 2.3 Keep port probing as readiness/external-backend detection only; do not inspect, adopt, or terminate existing listeners on `127.0.0.1:8765`.
- [x] 2.4 Ensure `BackendProcessManager.stop()` terminates only the current app-owned `Process` handle and leaves external backends untouched.
- [x] 2.5 Add a backend lifespan parent monitor that starts only when the parent identity environment variable is present and requests graceful process exit when the parent no longer matches.

## 3. Review and Verification

- [x] 3.1 Run focused Swift tests for the backend lifecycle manager and app delegate termination path.
- [x] 3.2 Run focused backend tests for the parent monitor.
- [x] 3.3 Run the relevant full Swift regression command: `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -destination 'platform=macOS'`.
- [x] 3.4 Run backend regression tests if backend lifespan code changed: `cd assistant_backend && pytest`.
- [x] 3.5 Run OpenSpec validation/status checks for `bind-backend-shutdown-to-app-exit`.
- [x] 3.6 Perform spec compliance review against `specs/daily-morning-agent/spec.md`, especially owned-child, parent-loss, external-backend, and no-port-ownership scenarios.
- [x] 3.7 Perform code quality review for process-safety, parent monitor reliability, external backend preservation, and testability.
- [x] 3.8 Manual QA: launch MalDaze from the current checkout, confirm the app-spawned backend listens on `127.0.0.1:8765`, quit with Cmd+Q, and confirm that backend exits.
