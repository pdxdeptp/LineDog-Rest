## Context

`AppViewModel` owns the timer mode, the active/suspended flags, the timer engines, and the pet display state. Today `stopTimers()` sets `chronoSessionSuspendedByUser = true`, but that flag is private memory only. A normal app launch initializes `mode` to `.auto`, sets `isChronoSessionActive = bootstrapAutoEngine`, and starts `AutoTimerEngine` when bootstrapping is enabled.

The requested behavior is specifically about user intent after pressing "停止计时": restarting MalDaze should keep the timer stopped and keep the resume affordance available.

## Goals / Non-Goals

**Goals:**

- Persist a user-stopped timer session across app relaunch.
- Restore the same suspended timer mode on launch so "恢复计时" resumes the expected engine.
- Keep automatic timer startup unchanged when there is no user-stopped snapshot.
- Clear the persisted snapshot when the user resumes, starts a new manual focus session, or changes timer mode.

**Non-Goals:**

- Persist precise countdown remaining time or current work/rest phase.
- Persist normal timer mode selection outside of the stopped-session snapshot.
- Change seven-minute reminders, hydration reminders, retired middle-column feature state, or backend behavior.

## Decisions

1. Store one `UserDefaults` snapshot key containing the suspended `AppViewModel.Mode.rawValue`.

   Rationale: the key's presence means "user-stopped session exists"; the value tells launch which mode to show before resume. This avoids a separate boolean and keeps migration simple. If the value is missing or invalid, launch falls back to current behavior.

   Alternative considered: store only a boolean. That would preserve stopped/running state but lose the stopped mode, causing a manual pause to relaunch as auto paused and resume the wrong engine.

2. Apply the snapshot only during bootstrapped app launch initialization.

   Rationale: production app launch uses `bootstrapAutoEngine: true`; tests and specialized initializers use `false` to avoid engine ticks. The snapshot should prevent production auto-start, but should not unexpectedly change test-only bootstrapping semantics unless a test explicitly covers the launch path.

   Alternative considered: always restore the snapshot regardless of `bootstrapAutoEngine`. That couples test setup to global defaults more tightly and makes isolated non-bootstrapped view model creation less predictable.

3. Clear the snapshot on explicit user actions that end the suspended-session meaning.

   Rationale: after `resumeTimers()`, `startManualFocus()`, or `setMode(_:)`, the app no longer represents the same user-stopped session. Clearing there preserves default auto startup for future launches.

## Risks / Trade-offs

- [Risk] A stale or invalid defaults value could keep the app stopped unexpectedly. → Mitigation: restore only recognized mode raw values; remove invalid values and continue with default startup.
- [Risk] Persisting only the stopped snapshot means normal mode selection still resets on launch. → Mitigation: this matches the narrow requirement and avoids introducing broader mode preference behavior.
- [Risk] Existing tests use `UserDefaults.standard` and can leak the new key. → Mitigation: add focused tests that clean up the key before and after assertions.
