## MODIFIED Requirements

### Requirement: Today header shows proportional focus cell grid
The learning desk panel today tab header SHALL display a focus timeline as a **grid of time cells** between the study/review budget rows and the task list. Each cell SHALL represent a fixed **30-minute** bucket. Cells SHALL use accent-colored **proportional fill** for successful focus time only (`source: completed` and active in-progress work). Abandoned attempts (`source: stoppedEarly`) SHALL NOT paint proportional success fill; they SHALL appear as **muted failed markers** at the mapped session start time within the cell.

#### Scenario: Default visible window is eight to midnight
- **WHEN** the user views the today tab header and no focus session overlaps `[today 00:00, today 08:00)` local time
- **THEN** the grid shows cells only for `[today 08:00, today 24:00)`
- **AND** no empty off-hours columns are reserved

#### Scenario: Off-hours activity expands the visible window leftward
- **WHEN** at least one completed session, in-progress segment, or failed marker overlaps `[today 00:00, today 08:00)` local time
- **THEN** the grid extends its visible start time leftward to the 30-minute cell boundary at or before the earliest such overlap
- **AND** the visible start time is not earlier than `today 00:00`
- **AND** the visible end time remains `today 24:00`

#### Scenario: Completed sessions paint proportional accent fill
- **WHEN** a finalized focus session has `source: completed` and overlaps part of a cell bucket
- **THEN** the cell paints an accent-colored sub-region covering only the proportional fraction of the cell width for that overlap

#### Scenario: Abandoned sessions paint failed markers only
- **WHEN** a finalized focus session has `source: stoppedEarly`
- **THEN** the grid shows a muted failed marker at the mapped `startedAt` position within the cell
- **AND** MalDaze does not paint proportional accent success fill for the elapsed partial duration

#### Scenario: In-progress work paints to now while timer runs
- **WHEN** a manual work segment is in progress and the timer is actively running (not user-paused)
- **THEN** cells overlapping `[startedAt, now]` show proportional accent fill through the current time
- **AND** the segment is not counted in summary `N` until finalized

#### Scenario: Paused work does not paint in-progress fill
- **WHEN** the user pauses the timer while a manual work segment exists
- **THEN** the grid does not show growing in-progress accent fill until the timer resumes
- **AND** no focus session JSON record is written for the pause action alone

#### Scenario: Summary beside the grid counts completed success only
- **WHEN** the focus cell grid is visible
- **THEN** the header shows `N 个 · X 分钟` on the same row as the grid
- **AND** `N` counts only finalized sessions with `source: completed` for today
- **AND** `X` counts only completed session minutes for today (exclude `stoppedEarly` and in-progress elapsed time)

#### Scenario: Hover popover respects Forest edit rules
- **WHEN** the user hovers or pins a timeline segment popover
- **THEN** completed sessions allow edit and delete
- **AND** failed markers allow delete only
- **AND** in-progress segments are read-only until completion

## MODIFIED Requirements

### Requirement: Manual focus pause preserves one pomodoro block
MalDaze manual focus SHALL follow Forest-style pomodoro continuity: pausing suspends the same work segment without finalizing it; abandoning writes a failed attempt.

#### Scenario: Pause does not finalize focus session
- **WHEN** the user pauses timers during manual work
- **THEN** MalDaze persists chrono paused state
- **AND** does not append a focus session record for the pause

#### Scenario: Resume continues same work segment
- **WHEN** the user resumes timers after pausing manual work
- **THEN** MalDaze restores the same work segment start time and countdown
- **AND** does not start a new focus session record until completion or abandon

#### Scenario: Abandon writes stoppedEarly
- **WHEN** the user switches away from manual mode or starts a new manual focus while a work segment exists
- **THEN** MalDaze finalizes the prior segment with `source: stoppedEarly`
- **AND** the timeline shows a failed marker for that attempt

#### Scenario: Natural completion writes completed
- **WHEN** manual work naturally enters rest
- **THEN** MalDaze finalizes the segment with `source: completed`
- **AND** the timeline paints accent success fill and counts the session in summary `N` and `X`
