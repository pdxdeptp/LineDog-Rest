## MODIFIED Requirements

### Requirement: Today view shows budget warnings and rollover badges

The learning desk panel SHALL display daily study budget usage, daily review budget usage, over-capacity indication for each bucket, rest-day state, project behind warnings, auto-rollover badges, and today completion progress derived from the `today` response.

#### Scenario: Over-capacity header for study and review
- **WHEN** `today` reports `study.total_minutes` greater than the configured daily study capacity or `review.total_minutes` greater than review budget
- **THEN** the panel header shows load and capacity for **both** study and review
- **AND** emphasizes whichever bucket is over budget

#### Scenario: Today completion progress
- **WHEN** the today tab is loaded and `today.progress` is present
- **THEN** the panel shows study and review completion as `done/total` with a visual progress indicator for each bucket
- **AND** updates after a successful complete or review action without requiring a manual full reload beyond the existing refresh chain

#### Scenario: Auto-roll badge
- **WHEN** a pending task has `auto_roll_days` greater than or equal to 1
- **THEN** the panel shows a rollover-day badge for that task row

#### Scenario: High rollover pinned strip
- **WHEN** one or more pending tasks have `auto_roll_days` greater than or equal to 3
- **THEN** the today tab shows a dedicated pinned strip listing those tasks above the main list
- **AND** activating a strip item scrolls the main list to the matching task row

### Requirement: Complete task from panel via Hermes CLI

MalDaze SHALL complete learning tasks from the panel by spawning `schedule.py complete --task-id <id>` and SHALL refresh the today view after a successful completion. MalDaze MAY optionally collect actual minutes before completion.

#### Scenario: Checkbox complete
- **WHEN** the user checks complete on a pending task row
- **THEN** MalDaze runs `schedule.py complete` for that `task_id`
- **AND** on success the task disappears from the refreshed today list

#### Scenario: Complete with optional actual minutes
- **WHEN** the user chooses complete-with-duration on a task row
- **THEN** MalDaze presents a lightweight editor defaulting to planned `duration_minutes`
- **AND** on confirm invokes `schedule.py complete --task-id <id> --actual-minutes <n>`

### Requirement: Dashboard learning panel displays today view

MalDaze SHALL present a learning desk panel in the Dashboard middle column that shows today's pending learning tasks by invoking Hermes `schedule.py rollover` followed by `schedule.py today` with `HERMES_HOME` set to the user's Hermes home directory. The today list SHALL support a user-toggle between flat ordering and grouping by project name while preserving Hermes `pending.index` order within each group.

#### Scenario: Open dashboard loads today list
- **WHEN** the user opens the desk pet Dashboard panel
- **THEN** MalDaze runs `schedule.py rollover` and `schedule.py today`
- **AND** the middle column renders pending tasks consistent with the `today` JSON output

#### Scenario: Group by project
- **WHEN** the user enables project grouping on the today tab
- **THEN** tasks are sectioned by `project_name`
- **AND** each section preserves the relative order from `pending[]`
