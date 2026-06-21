## Why

Manual focus suffers from **dual lifecycles** (engine phases vs `workSegmentStartedAt`) and from a **third user action—「停止计时 / 恢复计时」—that Forest does not have**. Pause/resume pretends to be Forest-style suspension but behaves as chrono suspend (including reconcile catch-up), producing contradictory UI (**剩余 8:07** vs **100 分钟进行中** vs **0 个 · 0 分钟**) and confusing product language. Users should face only Forest-honest choices during manual focus: **keep going, finish naturally, abandon, or start a new pomodoro**—not pause.

## What Changes

- **Remove user pause/resume entirely**: delete `stopTimers`, `resumeTimers`, `chronoSessionSuspendedByUser`, user-paused chrono snapshots,「停止计时 / 恢复计时」controls, and all **BREAKING** `PauseKind.user` / mode-only suspend persistence.
- **Manual focus actions become binary**:
  - **开始专注** — start engine when idle (after rest or no session).
  - **放弃当前番茄** — during manual work: stop engine + append `stoppedEarly` (dead tree); not resumable.
  - **Natural work→rest** — append `completed` (planted tree).
  - Starting focus while a work segment exists **must abandon first** (existing rule, now the only interrupt path).
- **Introduce `ManualFocusCoordinator`** + engine phase events + reconcile replay (fixes missed `completed` on relaunch).
- **Replace in-progress model** with `FocusPomodoroInProgress` capped to **current work phase** only; timeline/popover/status share one countdown source.
- **Chrono snapshot v3**: running-session restore **only** (crash/relaunch while timer was active); no user-suspended state; drop `workSegmentStartedAt`.
- **Auto (整点/半点) mode**: replace「停止计时」with **停止自动提醒** — stops auto engine, no focus JSON, **no resume** (re-enable by switching back to auto or relaunch policy as today for preferred mode).

## Capabilities

### New Capabilities

- `manual-focus-coordinator`: Phase-event-driven complete/abandon lifecycle, relaunch reconcile replay, pomodoro in-progress projection.

### Modified Capabilities

- `learning-desk-panel`: Capped in-progress timeline/popover; no paused empty state semantics.
- `desk-pet-controls`: Remove pause/resume timer controls; add explicit abandon; running-only chrono restore.

## Impact

- **Removed**: `stopTimers`, `resumeTimers`, `showResumeChronoButton`, user-paused chrono paths, legacy `suspendedTimerModeSnapshot` suspend UX (**BREAKING** for users who relied on resume).
- **New/Modified**: `ManualFocusCoordinator`, `ManualTimerEngine` phase events, `AppViewModel`, `DashboardRootView` timer quick actions, `ChronoSessionPersistence` v3.
- **Unchanged**: `focus-sessions.json`, Hermes, hydration「暂停喝水提醒」(unrelated domain).
- **Supersedes**: `redesign-focus-forest-philosophy` pause/resume requirements; prior draft of this change that retained chrono pause.
