## ADDED Requirements

### Requirement: Insert learning task from panel

MalDaze SHALL create a single learning task by spawning `schedule.py insert` with project id, title, duration, and scheduled date. Insert SHALL NOT cascade other tasks in Swift.

#### Scenario: Insert on chosen date
- **WHEN** the user submits the insert form with valid title, duration, and date
- **THEN** MalDaze runs `schedule.py insert` with the provided fields
- **AND** refreshes the today view on success
- **AND** does not modify other task dates locally

#### Scenario: Insert failure
- **WHEN** `insert` returns an error such as unknown project id
- **THEN** the panel shows the Hermes error without partial local state

### Requirement: Remove learning task from panel

MalDaze SHALL delete a single learning task by spawning `schedule.py remove --task-id <id>` after explicit user confirmation.

#### Scenario: Confirmed remove
- **WHEN** the user confirms removal on a task row
- **THEN** MalDaze runs `schedule.py remove` for that task id
- **AND** refreshes the today view on success

### Requirement: Week load tab

The learning desk panel SHALL provide a week-load tab that shows scheduled study load per day for a forward window of up to 28 days, SHALL display values in **hours** (not minutes), and SHALL highlight days that exceed the user's configured daily study capacity.

#### Scenario: Lazy load week data
- **WHEN** the user switches to the week-load tab
- **THEN** MalDaze loads week-load data via `schedule.py week-load` when available, or read-only aggregation from `projects.json`
- **AND** each day shows load and capacity in hours such as `2.5 小时 / 5 小时`
- **AND** over-capacity days are visually emphasized

### Requirement: Configurable daily study capacity in settings

MalDaze SHALL let the user configure daily study capacity in hours from Settings → Learning panel with a default of **5 hours**, range **1–12 hours**, step **0.5 hour**, and SHALL sync the value to Hermes `profile.json` as `daily_capacity_minutes`.

#### Scenario: Change capacity in settings
- **WHEN** the user adjusts the daily study capacity slider in Settings
- **THEN** MalDaze saves the hours value locally and writes `daily_capacity_minutes = hours × 60` to Hermes profile
- **AND** the learning panel refreshes today and week-load views to use the new capacity

### Requirement: Insert task project picker uses active projects

MalDaze SHALL populate the insert-task project picker from `schedule.py status` active projects, not only projects appearing in today's task list.

#### Scenario: Project with no tasks today
- **WHEN** the user opens the insert form and an active project has no tasks scheduled today
- **THEN** that project still appears in the project picker

### Requirement: Auto refresh on projects.json changes

MalDaze SHALL watch `~/.hermes/data/learning-assistant/projects.json` with debounced file events and SHALL refresh the today view when the file changes while the learning panel is visible.

#### Scenario: External Hermes edit
- **WHEN** Hermes or another tool updates `projects.json` while the dashboard is open
- **THEN** the learning panel refreshes today data within the debounce window
- **AND** does not run rollover on file events alone

### Requirement: Review pass and fail from panel

MalDaze SHALL offer pass and fail actions on review task rows by spawning `schedule.py review --task-id <id> --result passed|failed`.

#### Scenario: Review passed
- **WHEN** the user marks a review task as passed
- **THEN** MalDaze runs `review --result passed`
- **AND** refreshes the today view on success

#### Scenario: Review failed
- **WHEN** the user marks a review task as failed
- **THEN** MalDaze runs `review --result failed`
- **AND** refreshes the today view to reflect the next review scheduling created by Hermes
