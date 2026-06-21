## MODIFIED Requirements

### Requirement: Today header shows proportional focus cell grid
The learning desk panel today tab header SHALL display a focus timeline as a **grid of time cells** between the study/review budget rows and the task list. Each cell SHALL represent a fixed **30-minute** bucket. Cells SHALL use accent-colored **proportional fill** for successful focus time only (`source: completed` and active in-progress work). Abandoned attempts (`source: stoppedEarly`) SHALL appear as **muted failed markers** at session start. In-progress fill SHALL represent **only the current manual work phase** `[phaseStart, min(now, phaseEnd)]` where **`phaseStart ≤ now`**. The grid SHALL be supplied by **`FocusTimelinePresenter`** (cached skeleton + live overlay), not recomputed inside SwiftUI `body` on every `AppViewModel` tick.

#### Scenario: Default visible window is eight to midnight
- **WHEN** the user views the today tab header and no focus session overlaps `[today 00:00, today 08:00)` local time
- **THEN** the grid shows cells only for `[today 08:00, today 24:00)`
- **AND** no empty off-hours columns are reserved

#### Scenario: Off-hours activity expands the visible window leftward
- **WHEN** at least one completed session, in-progress segment, or failed marker overlaps `[today 00:00, today 08:00)` local time
- **THEN** the grid extends its visible start time leftward to the 30-minute cell boundary at or before the earliest such overlap
- **AND** the visible end time is not earlier than `today 00:00`
- **AND** the visible end time remains `today 24:00`

#### Scenario: Completed sessions paint proportional accent fill
- **WHEN** a finalized focus session has `source: completed` and overlaps part of a cell bucket
- **THEN** the cell paints an accent-colored sub-region covering only the proportional fraction of the cell width for that overlap

#### Scenario: Abandoned sessions paint failed markers only
- **WHEN** a finalized focus session has `source: stoppedEarly`
- **THEN** the grid shows a muted failed marker at the mapped `startedAt` position
- **AND** MalDaze does not paint proportional accent success fill for partial duration

#### Scenario: In-progress work paints current pomodoro phase only
- **WHEN** manual work is actively running
- **THEN** cells overlapping `[phaseStart, min(now, phaseEnd)]` show proportional accent fill
- **AND** `phaseStart` is not later than `now`
- **AND** the segment is not counted in summary `N` until finalized

#### Scenario: No in-progress fill after abandon or idle
- **WHEN** the user has abandoned manual work or manual timer is not running
- **THEN** the grid does not show in-progress accent fill
- **AND** failed markers or completed fills reflect finalized sessions only

#### Scenario: Rest phase does not paint in-progress fill
- **WHEN** manual timer is in rest phase
- **THEN** the grid does not show in-progress accent fill

#### Scenario: Summary counts completed success only
- **WHEN** the focus cell grid is visible
- **THEN** the header shows `N 个 · X 分钟`
- **AND** `N` and `X` count only finalized `source: completed` sessions for today

#### Scenario: In-progress popover uses pomodoro-scoped progress
- **WHEN** the user hovers an in-progress timeline segment
- **THEN** the popover shows phase start/end, elapsed within phase, and remaining countdown
- **AND** the popover is read-only

#### Scenario: Finalized segment popover edit rules
- **WHEN** the user hovers a finalized success or failed marker
- **THEN** completed sessions allow edit and delete
- **AND** failed markers allow delete only

#### Scenario: Timeline does not rebuild on status line tick alone
- **WHEN** only the desk-pet status line countdown updates during active manual work
- **THEN** the today header focus grid does not rebuild its cached day skeleton
- **AND** only the in-progress overlay may update at most once per displayed second while the header is visible

## REMOVED Requirements

_None._
