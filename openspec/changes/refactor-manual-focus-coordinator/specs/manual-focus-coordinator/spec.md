## ADDED Requirements

### Requirement: Manual focus lifecycle is coordinator-owned
MalDaze SHALL route all manual focus session writes and in-progress projection through `ManualFocusCoordinator`. The coordinator SHALL be the only component that appends to `FocusSessionStore` for manual pomodoro events. `AppViewModel` SHALL NOT maintain parallel focus timestamps such as `workSegmentStartedAt`.

#### Scenario: Completed pomodoro writes through coordinator
- **WHEN** manual work phase ends and the engine emits a work-completed transition
- **THEN** the coordinator appends a focus session with `source: completed`
- **AND** no other layer writes the same completion directly

#### Scenario: Abandon writes through coordinator
- **WHEN** the user abandons the current manual work phase
- **THEN** the coordinator appends `source: stoppedEarly` for `[phaseStart, now]` of the current work phase only
- **AND** stops the manual timer engine

### Requirement: Engine phase events are the focus lifecycle input
`ManualTimerEngine` SHALL emit explicit phase transition events for work start, work complete, rest start, and rest end. Live ticks and relaunch reconcile SHALL emit the same event types through the same code path.

#### Scenario: Live work-to-rest emits completion
- **WHEN** a running manual work phase reaches its configured duration
- **THEN** the engine emits a work-completed event with that phase's start and end timestamps
- **AND** the coordinator appends a completed focus session

#### Scenario: Relaunch reconcile replays missed completions
- **WHEN** app restores a running manual chrono snapshot whose phaseEnd is far in the past
- **THEN** the engine emits one work-completed event for each fully elapsed work phase during catch-up
- **AND** the coordinator appends each as completed before exposing current in-progress projection

### Requirement: In-progress projection uses current work phase bounds only
The coordinator SHALL expose `FocusPomodoroInProgress` from the engine's current manual work phase only: `startedAt`, `endsAt`, and `remainingSeconds`.

#### Scenario: In-progress interval is capped to one pomodoro
- **WHEN** a manual work phase is in progress
- **THEN** timeline and popover use `[startedAt, min(now, endsAt)]`
- **AND** elapsed time never exceeds the configured work duration for that phase

#### Scenario: Rest phase clears in-progress projection
- **WHEN** the engine enters manual rest phase
- **THEN** in-progress projection is nil
- **AND** the just-completed pomodoro remains visible as a finalized session

### Requirement: Manual focus has no user pause or resume
MalDaze SHALL NOT provide user-facing pause or resume for manual pomodoro focus. MalDaze SHALL NOT persist user-suspended chrono state for later resume. The only user-initiated interrupt during manual work SHALL be abandon.

#### Scenario: No stop-timer suspend path
- **WHEN** the user is in manual mode with an active work phase
- **THEN** MalDaze does not offer「停止计时」or「恢复计时」actions
- **AND** offers「放弃当前番茄」instead

#### Scenario: Abandon is not resumable
- **WHEN** the user abandons the current manual work phase
- **THEN** MalDaze does not persist a resumable chrono snapshot for that pomodoro
- **AND** the user must tap「开始专注」to start a new pomodoro

#### Scenario: Legacy user-paused snapshot is cleared
- **WHEN** app loads a chrono snapshot with legacy user-paused kind
- **THEN** MalDaze clears the suspend snapshot
- **AND** does not show a resume control

### Requirement: Chrono persistence is running-session restore only
Chrono snapshots SHALL persist only actively running timer sessions for crash/relaunch recovery. MalDaze SHALL NOT persist user-initiated suspended timer state.

#### Scenario: Running relaunch restores engine and focus accounting
- **WHEN** app relaunches with a valid running manual chrono snapshot
- **THEN** MalDaze restores the manual engine phase and replays missed focus completions
- **AND** derives work phase start from phaseEnd and configured work duration

#### Scenario: Idle relaunch does not restore manual work
- **WHEN** the user previously abandoned or never started manual focus
- **THEN** app launch does not restore an in-progress manual work phase from chrono
