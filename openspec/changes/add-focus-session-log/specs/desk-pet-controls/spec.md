## ADDED Requirements

### Requirement: Manual focus session persistence
MalDaze SHALL persist each completed manual-pomodoro work segment as a local focus session with start time, end time, and duration in minutes. Sessions SHALL be stored in MalDaze-owned local JSON under Application Support and SHALL NOT be written to Hermes or learning daily logs.

#### Scenario: Natural work segment completion
- **WHEN** manual timer mode is active and a work segment ends by transitioning into rest
- **THEN** the system appends a focus session with `startedAt`, `endedAt`, `durationMinutes`, and `source: completed`
- **AND** the session is retained in persistent storage without day-based deletion

#### Scenario: Early stop during work
- **WHEN** manual timer mode is active, a work segment is in progress, and the user stops timers before rest begins
- **THEN** the system appends a focus session with actual elapsed minutes and `source: stoppedEarly`
- **AND** no session is written when stop occurs during rest

#### Scenario: Auto half-hour mode unchanged
- **WHEN** timer mode is automatic half-hour / half-hour rest only
- **THEN** the system does not append focus sessions for that mode in this change

#### Scenario: Session reserves future labels
- **WHEN** a focus session is persisted
- **THEN** the record includes an empty `labels` collection for future annotation
- **AND** P1 does not require the user to attach labels

### Requirement: Dashboard today focus visualization
The Dashboard right controls column SHALL display today's manual focus sessions between the status chip and primary timer actions, including a live in-progress row while a work segment is running.

#### Scenario: Summary line
- **WHEN** the Dashboard panel shows the today-focus section
- **THEN** it displays a summary of the form `N 个番茄 · 共 X 分钟`
- **AND** `N` counts only finalized sessions for the current local calendar day
- **AND** `X` includes finalized session minutes plus elapsed minutes of an in-progress work segment when one exists
- **AND** the summary does not split counts between completed and early-stopped sessions

#### Scenario: Finalized session row format
- **WHEN** a finalized session for today is listed
- **THEN** the row shows the time range as `HH:mm–HH:mm` using local time
- **AND** the row shows the session duration in minutes
- **AND** early-stopped sessions additionally show a secondary “提前结束” indicator

#### Scenario: In-progress session row
- **WHEN** a manual work segment is in progress
- **THEN** the list shows a top row formatted as `HH:mm–进行中 · 已 N 分钟`
- **AND** `N` updates on whole-minute boundaries consistent with timer UI refresh
- **AND** the in-progress row is not counted in summary `N` until finalized

#### Scenario: Empty today list
- **WHEN** there are no finalized or in-progress sessions for the current local calendar day
- **THEN** the section shows an empty-state message equivalent to “今天还没有番茄”

#### Scenario: Today-only display with full retention
- **WHEN** historical focus sessions exist for prior calendar days
- **THEN** the Dashboard lists only sessions whose session date matches today
- **AND** older sessions remain stored without automatic purge
