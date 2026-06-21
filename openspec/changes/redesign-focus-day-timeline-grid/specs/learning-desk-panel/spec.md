## ADDED Requirements

### Requirement: Today header shows proportional focus cell grid
The learning desk panel today tab header SHALL display a focus timeline as a **grid of time cells** between the study/review budget rows and the task list. Each cell SHALL represent a fixed **30-minute** bucket. Cells SHALL use a GitHub-like discrete grid layout, but **fill inside each cell SHALL be proportional accent color** (not whole-cell on/off, not discrete level buckets such as GitHub contribution tiers) based on the overlap between `[cellStart, cellEnd)` and actual focus session intervals `[startedAt, endedAt]` (or `[startedAt, now]` while in progress).

#### Scenario: Default visible window is eight to midnight
- **WHEN** the user views the today tab header and no focus session overlaps `[today 00:00, today 08:00)` local time
- **THEN** the grid shows cells only for `[today 08:00, today 24:00)`
- **AND** no empty off-hours columns are reserved

#### Scenario: Off-hours activity expands the visible window leftward
- **WHEN** at least one focus session or in-progress segment overlaps `[today 00:00, today 08:00)` local time
- **THEN** the grid extends its visible start time leftward to the 30-minute cell boundary at or before the earliest such overlap
- **AND** the visible start time is not earlier than `today 00:00`
- **AND** the visible end time remains `today 24:00`

#### Scenario: Partial fill from actual session interval
- **WHEN** a finalized focus session overlaps only part of a cell's time bucket (for example 14:10–14:25 within 14:00–14:30)
- **THEN** the cell paints an accent-colored sub-region covering only the proportional fraction of the cell width for that overlap
- **AND** the cell is not fully filled unless the session covers the entire bucket

#### Scenario: Fill grows left to right within a cell
- **WHEN** a cell paints proportional accent fill for a session overlap
- **THEN** each sub-region is anchored from the cell's leading (left) edge at the time-proportional offset
- **AND** the sub-region extends toward the trailing (right) edge by the overlap duration fraction
- **AND** MalDaze does not anchor fill from the trailing edge or grow right-to-left

#### Scenario: Continuous ratio not discrete buckets
- **WHEN** focus time within a 30-minute cell totals three minutes
- **THEN** the painted sub-region width equals three thirtieths (10%) of the cell width
- **AND** MalDaze does not round the fill to a small set of discrete contribution levels

#### Scenario: Session spans multiple cells
- **WHEN** a focus session spans more than one cell bucket
- **THEN** each affected cell paints its own proportional accent sub-region
- **AND** adjacent filled sub-regions use the same accent styling so continuity is visible across cell boundaries

#### Scenario: Early stop and completed sessions both paint
- **WHEN** a session is finalized with `source: stoppedEarly` or `source: completed`
- **THEN** the timeline paints proportional accent fill from `startedAt` to `endedAt` for both sources
- **AND** painting is based on time overlap, not on pomodoro count per cell

#### Scenario: In-progress work paints to now
- **WHEN** a manual work segment is in progress
- **THEN** cells overlapping `[startedAt, now]` show proportional accent fill through the current time
- **AND** the segment is not counted in summary `N` until finalized

#### Scenario: Midnight-spanning session within today
- **WHEN** a session started today spans from before midnight to after midnight (for example 23:40–00:20 local)
- **THEN** the portion within `[today 08:00, today 24:00)` paints in the default window
- **AND** the portion within `[today 00:00, today 08:00)` contributes to off-hours expansion and paints in the expanded morning cells

#### Scenario: Summary beside the grid
- **WHEN** the focus cell grid is visible
- **THEN** the header shows `N 个 · X 分钟` on the same row as the grid
- **AND** `N` counts only finalized sessions with `source: completed` for today
- **AND** `X` includes finalized seconds plus in-progress elapsed seconds for the full calendar day regardless of visible window

#### Scenario: Empty focus day
- **WHEN** there are no session overlaps and no in-progress segment for today
- **THEN** the header shows an empty-state message equivalent to “今天还没有专注”
- **AND** it does not paint fake accent fill

#### Scenario: No per-session list
- **WHEN** the user views the today tab header
- **THEN** MalDaze does not list individual session rows with times, durations, or “提前结束” badges in the learning panel

### Requirement: Today header shows inline completion counts without progress bars
The learning desk panel today tab header SHALL show Hermes study and review completion counts as inline numeric text on the same lines as load/capacity, and SHALL NOT render linear progress bars for those completion metrics in the header.

#### Scenario: Study completion inline with load
- **WHEN** the today response includes study progress counts
- **THEN** the study budget line shows load/capacity and `完成 done/total` on the same line
- **AND** no separate linear progress bar is shown for study completion in the header

#### Scenario: Review completion inline with load
- **WHEN** the today response includes review progress counts
- **THEN** the review budget line shows load/capacity and `完成 done/total` on the same line
- **AND** no separate linear progress bar is shown for review completion in the header

### Requirement: Learning panel receives focus projection from AppViewModel
The learning desk panel SHALL read today focus projection from `AppViewModel` and SHALL NOT maintain a second copy of focus session data for the cell grid.

#### Scenario: Single SSOT for grid input
- **WHEN** the cell grid renders
- **THEN** it derives visible window bounds and per-cell proportional fills from `AppViewModel` focus session projection and the current clock
- **AND** it does not read `focus-sessions.json` independently of the shared projection path
