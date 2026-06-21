## Context

MalDaze manual pomodoro uses `ManualTimerEngine` and `FocusSessionStore`. `AppViewModel` bridges them with shadow fields (`workSegmentStartedAt`) and a parallel **user pause** path (`stopTimers` / `resumeTimers`, `ChronoSessionRecord.pauseKind.user`). Forest-aligned accounting (complete / stoppedEarly / completed-only summary) was added in UI, but **pause/resume is not a Forest concept** and conflicts with honest product language.

Users need a single mental model: **one pomodoro = one work phase**; outcomes are **planted (completed)** or **dead (stoppedEarly)**; **no suspend-and-continue**.

## Goals / Non-Goals

**Goals:**

- Manual focus user actions: **开始专注**, **放弃当前番茄**, plus natural completion on rest entry.
- Engine phase events + `ManualFocusCoordinator` as sole focus writer.
- In-progress projection from **current work phase only**; status line, popover, and grid share one remaining countdown.
- Reconcile on **running relaunch** replays missed `completed` before showing in-progress.
- Remove all user-pause persistence and UI.

**Non-Goals:**

- Forest-style pause (explicitly rejected).
- Auto-mode focus session JSON (unchanged: none).
- Hermes task-time integration.
- Hydration reminder pause semantics (unchanged).

## Decisions

### D1: Remove user pause/resume completely

**Decision**: Delete `stopTimers`, `resumeTimers`, `chronoSessionSuspendedByUser`, `showResumeChronoButton`, `persistUserPaused`, bootstrap plans `restoreUserPaused` / `restoreUserPausedModeOnly`, and Dashboard「停止计时 / 恢复计时」. Clear legacy `MalDazeDefaults.suspendedTimerModeSnapshot` on migration.

**Rationale**: Forest-honest manual focus has no third state. Pause caused dual SSOT bugs and false expectations.

**Alternative rejected**: Keep pause as non-Forest chrono layer — user rejected; keep product language consistent.

### D2: Manual work interrupt = abandon only

**Decision**: New primary action during manual **work** phase: **放弃当前番茄** (`abandonManualFocus()`):
- Stop manual engine
- Coordinator appends `stoppedEarly` for current phase `[phaseStart, now]`
- Clear in-progress projection; pet returns idle/paused-outline until next start

**Rationale**: Maps to Forest "tree dies". Replaces ambiguous「停止计时」.

During **rest** phase: no abandon of focus record (work already completed). Existing skip-rest / wait behavior unchanged.

### D3: `ManualFocusCoordinator` + phase events (no `pause()`)

**Decision**: Coordinator handles `workStarted`, `workCompleted`, `abandonCurrentWorkPhase`, `projection(now:)`. Engine emits events on live tick **and** reconcile loop.

**Rationale**: Fixes relaunch missed completions without pause path.

### D4: `FocusPomodoroInProgress` from engine work phase

**Decision**:

```swift
struct FocusPomodoroInProgress {
    let startedAt: Date
    let endsAt: Date
    let remainingSeconds: Int
}
```

Timeline: `[startedAt, min(now, endsAt)]`. Rest phase → nil in-progress.

### D5: Chrono v3 — running restore only

**Decision**: `ChronoSessionRecord` stores `mode`, `phase`, `phaseEnd` for **active running** sessions (`pauseKind` removed or always implicit running). Persist on terminate/resign-active while `isChronoSessionActive`. Bootstrap: if valid running snapshot → restore + reconcile replay; else preferred mode idle.

**No** user-suspended snapshot. App relaunch after user **abandoned** or **idle** → no chrono restore.

**Migration**: v2 records with `pauseKind.user` → treat as idle on load (one-time clear); do not show「恢复计时」.

### D6: Auto mode stop without resume

**Decision**: While auto engine running, show **停止自动提醒** (replaces stop timer). Stops auto engine; no focus JSON; no resume button. User re-enables by selecting auto mode again (existing `setMode(.auto)` behavior) or app relaunch per preferred mode.

**Rationale**: Parallel removal of pause semantics; auto never had focus sessions.

### D7: Start while active = abandon then start

**Decision**: `startManualFocus()` when work segment exists: coordinator `abandonCurrentWorkPhase` then `manualEngine.start()`. UI should prefer showing **放弃** instead of implicit double-action when possible.

### D8: UI copy

**Decision**:

| State | Primary action |
|-------|----------------|
| Manual idle | 开始专注 |
| Manual working | 放弃当前番茄 |
| Manual resting | (rest UI; skip via pet if enabled) |
| Auto running | 停止自动提醒 |
| Auto idle | (mode picker) |

Remove status lines mentioning「已暂停」「恢复计时」.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Users lose convenient suspend | Explicit product choice; shorter copy explains Forest model |
| v2 paused snapshot users lose in-flight pomodoro | Migration clears suspend; acceptable BREAKING note |
| Meeting interrupt forces abandon | Aligns with Forest; optional future "short break" is out of scope |
| Reconcile on relaunch still complex | Same event pipeline as live; tested |

## Migration Plan

1. Engine events + replay tests.
2. Coordinator without pause API.
3. Remove pause/resume from AppViewModel + chrono + Dashboard.
4. Add abandon action + chrono v3 running-only.
5. Timeline/popover capped projection.
6. Clear legacy suspend keys on first launch after upgrade.

## Open Questions

- None blocking.
