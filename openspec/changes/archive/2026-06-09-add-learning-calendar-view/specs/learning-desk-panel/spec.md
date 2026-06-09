## ADDED Requirements

### Requirement: Schedule tab with month navigator and day agenda

MalDaze SHALL provide a **Schedule** tab in the learning desk panel that replaces the week-load tab. The tab SHALL combine a month mini-calendar navigator at the top and a scrollable day agenda list below, both sourced from Hermes `schedule.py schedule-range` with `HERMES_HOME` set.

#### Scenario: Open schedule tab loads range
- **WHEN** the user switches to the Schedule tab
- **THEN** MalDaze invokes `schedule.py schedule-range` for the visible month (and extends through active project deadlines per CLI rules)
- **AND** renders the month navigator and per-day agenda sections from the JSON response
- **AND** does not read Feishu calendar as a task source

#### Scenario: Month navigation
- **WHEN** the user moves to the previous or next month in the navigator
- **THEN** MalDaze reloads `schedule-range` for that month
- **AND** updates both the mini-calendar and agenda list

#### Scenario: Select day in mini-calendar
- **WHEN** the user taps a day cell in the mini-calendar
- **THEN** the agenda scrolls to or emphasizes that date's section
- **AND** the selected day is visually distinct from today and other days

#### Scenario: Agenda shows task detail per day
- **WHEN** a day has pending or review tasks in the range response
- **THEN** the agenda lists each task with project name, title, duration, and task type indicators consistent with the today tab
- **AND** each day header shows study load in **hours** against the configured daily capacity and highlights over-capacity days

#### Scenario: Rest and empty days
- **WHEN** a day is marked `is_rest_day: true`
- **THEN** the agenda shows an explicit rest-day state for that section
- **WHEN** a work day has no incomplete tasks
- **THEN** the agenda shows an empty-day state for that section

#### Scenario: Tasks after project deadline visible
- **WHEN** a task is scheduled after its project's deadline (including repack overflow)
- **THEN** the agenda marks that task or day with visible deadline-exceeded emphasis
- **AND** the user can identify overflow without opening the projects tab only

### Requirement: Schedule tab supports light task actions

The Schedule tab agenda SHALL reuse the same Hermes CLI write paths as the today tab for complete, move, insert context, and review pass/fail on eligible rows.

#### Scenario: Complete from agenda
- **WHEN** the user completes a task from the schedule agenda
- **THEN** MalDaze runs `schedule.py complete` for that task id
- **AND** refreshes the schedule range after success

#### Scenario: Move from agenda
- **WHEN** the user postpones or moves a task from the schedule agenda
- **THEN** MalDaze uses the existing move dry-run preview and confirmation flow
- **AND** refreshes the schedule range after a successful move

## MODIFIED Requirements

### Requirement: Week load tab displays hours

The learning desk panel SHALL provide a **Schedule** tab (replacing the former week-load tab) that shows per-day scheduled study load in **hours** and task-level agenda detail via `schedule.py schedule-range`. Days exceeding the configured daily study or review capacity SHALL be visually emphasized in both the month navigator and agenda headers.

#### Scenario: Schedule tab lazy load
- **WHEN** the user switches to the Schedule tab
- **THEN** MalDaze loads data via `schedule.py schedule-range`
- **AND** displays each day with hours such as load versus capacity and the day's task list

#### Scenario: Capacity settings apply to schedule view
- **WHEN** the user changes daily study capacity in MalDaze Settings → Learning panel
- **THEN** the schedule tab uses the updated capacity for over-capacity highlighting on next load
