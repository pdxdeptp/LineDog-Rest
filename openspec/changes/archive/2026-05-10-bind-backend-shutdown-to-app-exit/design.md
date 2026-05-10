## Context

`BackendProcessManager` currently probes `127.0.0.1:8765` on app launch. If the port is free, it spawns `assistant_backend/.venv/bin/uvicorn src.main:app --host 127.0.0.1 --port 8765` and keeps the in-memory `Process` reference. If the port is already bound, it treats the backend as external and does not stop it.

The desired product behavior is that a backend started by MalDaze exits with MalDaze. The important design correction is that ownership should come from the explicit parent-child relationship at spawn time, not from later inspecting whatever process happens to listen on a hard-coded port.

Recommended lifecycle:

```text
MalDaze.app
  ├─ 8765 free
  │   └─ spawn app-private backend child
  │       ├─ Swift keeps Process handle
  │       ├─ backend receives parent identity
  │       └─ backend exits if parent disappears
  └─ 8765 occupied
      └─ treat as external backend for connectivity only

Cmd+Q / terminate
  ├─ owned child exists → graceful terminate child
  └─ external backend → leave untouched
```

## Goals / Non-Goals

**Goals:**

- Ensure Cmd+Q / app termination shuts down the backend child that MalDaze explicitly spawned.
- Ensure the backend also exits if the MalDaze parent disappears without running normal termination hooks.
- Keep existing development behavior where a manually running backend on `8765` can serve the app without being killed by app exit.
- Keep port probing as readiness detection only.
- Make lifecycle decisions testable without spawning or killing real uvicorn processes in unit tests.

**Non-Goals:**

- Do not infer ownership by scanning `lsof` output, matching command lines, or killing arbitrary listeners on `8765`.
- Do not reintroduce the KeepAlive backend LaunchAgent as the default lifecycle mechanism.
- Do not change FastAPI routes, database schema, APScheduler semantics, or learning assistant data contracts.
- Do not implement a packaged helper/XPC service in this change.

## Decisions

### Decision 1: Use explicit child-process ownership as the only normal kill authority

`BackendProcessManager` should only terminate a backend process when it has the `Process` handle for the child it spawned during the current app run. If the app starts and `8765` is already occupied, the manager may mark the service as reachable but must not adopt or terminate that listener.

Rationale: this follows normal desktop-app process ownership. A port tells us connectivity, not authority.

Alternative considered: inspect the port listener, match uvicorn command/path, and terminate matching processes. This can clean some orphaned states, but it is a cleanup heuristic, not a lifecycle model, and it risks surprising users who intentionally launched a backend from the same checkout.

### Decision 2: Add backend self-shutdown on parent loss

When Swift spawns uvicorn, it should pass a small parent identity signal, such as `MALDAZE_PARENT_PID`, into the backend environment. During FastAPI lifespan startup, the backend should start a lightweight async monitor. If the backend observes that its parent process is no longer the expected MalDaze process, it should request graceful process termination.

Rationale: `applicationWillTerminate` is not guaranteed on crash, force quit, or some development interruptions. Parent-loss self-shutdown prevents the orphan problem at the source instead of trying to rediscover orphans later.

Alternative considered: pass an inherited control pipe and exit when the pipe closes. This is also a strong design and may be preferable later, but it is more plumbing in Swift `Process` and Python bootstrap. Parent PID monitoring is smaller and adequate for this local development-oriented backend.

### Decision 3: Keep port probing limited to readiness and external backend detection

The manager may continue checking `127.0.0.1:8765` to decide whether to spawn a backend and when to notify the UI that the backend is ready. If the port is already bound before spawn, the manager treats it as external for the duration of the app run and skips shutdown.

Rationale: this preserves the current useful development behavior without coupling shutdown authority to the port.

### Decision 4: Test the decision logic through small injected seams

Swift tests should not kill real processes. Factor process termination and environment construction behind small internal seams where needed. Backend tests should exercise the parent-monitor decision using injected parent PID/current PPID functions or a small monitor helper, not by killing the test runner's parent.

Rationale: lifecycle logic is safety-sensitive; tests should cover owned-child and external-backend branches deterministically.

## Risks / Trade-offs

- [Risk] Parent PID monitoring can lag by the polling interval. → Mitigation: keep the interval short enough for local cleanup, and still use Swift's direct `Process.terminate()` on normal app exit.
- [Risk] PID semantics vary after parent death and reparenting. → Mitigation: compare the current parent process against the expected parent; if it no longer matches, exit conservatively from the app-owned backend.
- [Risk] Manual uvicorn started with `MALDAZE_PARENT_PID` accidentally set could self-exit. → Mitigation: only Swift-spawned backend sets this environment variable during normal app launch; document it as an internal control variable.
- [Risk] Existing orphaned backends from before this change will not be cleaned automatically. → Mitigation: treat that as a one-time developer cleanup issue, not product lifecycle behavior; document a manual cleanup command or add a future explicit cleanup affordance if needed.

## Migration Plan

1. Add failing Swift tests for owned-child shutdown and external-backend preservation.
2. Add failing backend tests for parent-monitor behavior when the expected parent remains vs. disappears.
3. Pass `MALDAZE_PARENT_PID` when Swift spawns uvicorn.
4. Add backend lifespan monitor that exits the uvicorn process when parent identity no longer matches.
5. Keep `applicationWillTerminate` calling `BackendProcessManager.stop()` for normal graceful shutdown.
6. Manually QA by launching MalDaze from the current checkout, confirming the app-spawned backend listens on `127.0.0.1:8765`, quitting with Cmd+Q, and confirming that backend exits.

Rollback: remove the parent environment variable and backend monitor, returning to direct Swift `Process.terminate()` only.

## Open Questions

- Should we document a one-off developer cleanup command for existing orphaned `uvicorn src.main:app` processes, or leave cleanup entirely manual?
- Future native helper choices are tracked in the learning-assistant backlog: evaluate XPC Service if the backend boundary should become more App Store-native, and evaluate SMAppService LoginItem / LaunchAgent only if the product should run learning-assistant work after the main app quits.
