# learning-desk-panel Specification

## Purpose

MalDaze Dashboard middle-column learning panel: read today/week load from Hermes `schedule.py`, light write via CLI, daily capacity configurable in Settings (hours, default 5h, synced to Hermes profile).
## Requirements
### Requirement: Dashboard learning panel displays today view

MalDaze SHALL present a learning desk panel in the Dashboard middle column that shows today's pending learning tasks by invoking Hermes `schedule.py rollover` followed by `schedule.py today` with `HERMES_HOME` set to the user's Hermes home directory.

#### Scenario: Open dashboard loads today list
- **WHEN** the user opens the desk pet Dashboard panel
- **THEN** MalDaze runs `schedule.py rollover` and `schedule.py today`
- **AND** the middle column renders pending tasks consistent with the `today` JSON output
- **AND** the panel does not read Feishu calendar as a task source

#### Scenario: Manual refresh
- **WHEN** the user taps the learning panel refresh control
- **THEN** MalDaze re-runs `rollover` and `today`
- **AND** the displayed list updates to match the latest JSON

### Requirement: Today view shows budget warnings and rollover badges

The learning desk panel SHALL display daily study budget usage, over-capacity indication, rest-day state, project behind warnings, and auto-rollover badges derived from the `today` response and nested task fields.

#### Scenario: Over-capacity header
- **WHEN** `today` reports `study.total_minutes` greater than the user's configured daily study capacity
- **THEN** the panel header shows load and capacity in **hours** with visible over-budget emphasis
- **AND** the task list remains interactive

#### Scenario: Daily capacity from settings
- **WHEN** the user changes daily study capacity in MalDaze Settings → Learning panel
- **THEN** MalDaze persists the value in app settings and writes `daily_capacity_minutes` to Hermes `profile.json`
- **AND** the today header and week-load tab use the updated capacity for display and over-capacity highlighting

#### Scenario: Auto-roll badge
- **WHEN** a pending task has `auto_roll_days` greater than or equal to 1
- **THEN** the panel shows a rollover-day badge for that task row

#### Scenario: Rest day
- **WHEN** `today` reports `is_rest_day: true`
- **THEN** the panel shows a rest-day state
- **AND** an empty pending list is presented as expected rest behavior rather than an error

### Requirement: Complete task from panel via Hermes CLI

MalDaze SHALL complete learning tasks from the panel by spawning `schedule.py complete --task-id <id>` and SHALL refresh the today view after a successful completion.

#### Scenario: Checkbox complete
- **WHEN** the user checks complete on a pending task row
- **THEN** MalDaze runs `schedule.py complete` for that `task_id`
- **AND** on success the task disappears from the refreshed today list
- **AND** MalDaze does not mutate `projects.json` directly

#### Scenario: Complete failure is visible
- **WHEN** `complete` exits with an error or prints an `error` field
- **THEN** the panel shows the failure to the user
- **AND** the task row remains incomplete in the UI until a successful retry

### Requirement: Move task dates from panel via Hermes CLI

MalDaze SHALL postpone or reschedule tasks by spawning `schedule.py move --task-id <id> --new-date <YYYY-MM-DD>` and SHALL show a confirmation step that includes cascade impact before applying the move when dry-run preview is available.

#### Scenario: Postpone to tomorrow
- **WHEN** the user chooses postpone-to-tomorrow on a task row
- **THEN** MalDaze computes tomorrow's local date
- **AND** presents cascade preview when `move --dry-run` is available
- **AND** applies `move` only after user confirmation

#### Scenario: Move rejected by Hermes
- **WHEN** `move` rejects the operation such as moving before today or cascade into the past
- **THEN** the panel displays the Hermes error message
- **AND** MalDaze does not apply local date changes in Swift

### Requirement: Panel does not reimplement learning scheduling algorithms

MalDaze SHALL NOT implement learning scheduling algorithms including move cascade, review-chain generation, rollover, or initial plan packing in Swift or local storage. All scheduling semantics SHALL remain in Hermes `schedule.py`.

#### Scenario: No Swift cascade
- **WHEN** the user moves a task date from the panel
- **THEN** MalDaze invokes only the Hermes CLI
- **AND** does not compute or persist cascaded dates locally

### Requirement: Learning panel error and empty states

The learning desk panel SHALL present explicit empty and error states when Hermes is unavailable or today has no work.

#### Scenario: Hermes script missing
- **WHEN** `schedule.py` cannot be executed
- **THEN** the middle column shows an error card with remediation guidance
- **AND** left reminder and right desk-pet controls remain usable

#### Scenario: No pending tasks on a work day
- **WHEN** `pending_count` is zero and `is_rest_day` is false
- **THEN** the panel shows a no-tasks-today empty state

### Requirement: Schedule tab with month navigator and day agenda

MalDaze SHALL provide a **Schedule** tab in the learning desk panel that replaces the week-load tab. The tab SHALL combine a month mini-calendar navigator at the top and a scrollable day agenda list below, both sourced from Hermes `schedule.py schedule-range` with `HERMES_HOME` set.

#### Scenario: Open schedule tab loads range
- **WHEN** the user switches to the Schedule tab
- **THEN** MalDaze invokes `schedule.py schedule-range` for the visible month
- **AND** renders the month navigator and per-day agenda sections from the JSON response
- **AND** does not read Feishu calendar as a task source

#### Scenario: Month navigation
- **WHEN** the user moves to the previous or next month in the navigator
- **THEN** MalDaze reloads `schedule-range` for that month
- **AND** updates both the mini-calendar and agenda list

#### Scenario: Capacity settings apply to schedule view
- **WHEN** the user changes daily study capacity in MalDaze Settings → Learning panel
- **THEN** the schedule tab uses the updated capacity for over-capacity highlighting on next load

### Requirement: Insert and remove tasks from panel

MalDaze SHALL support `schedule.py insert` and `schedule.py remove` from the panel with confirmation on remove.

#### Scenario: Remove task with confirmation
- **WHEN** the user deletes a task from the today or schedule agenda
- **THEN** MalDaze shows a confirmation dialog before invoking `schedule.py remove`

### Requirement: Auto refresh on projects.json changes

MalDaze SHALL watch Hermes `projects.json` with debounced file events and refresh the visible tab's data without rollover while the panel is visible. File events SHALL invalidate cached project status and schedule-range data so other tabs show fresh data when selected.

#### Scenario: External edit while on today tab
- **WHEN** `projects.json` changes while the user is on the today tab
- **THEN** MalDaze refreshes today data within the debounce window
- **AND** invalidates project status cache for a subsequent project-tab visit

### Requirement: Review pass and fail from panel

MalDaze SHALL offer pass and fail actions on review rows via `schedule.py review`.

#### Scenario: Review from today row
- **WHEN** the user marks a review task passed or failed
- **THEN** MalDaze invokes `schedule.py review` with the appropriate result

### Requirement: Panel does not depend on external calendars

MalDaze learning desk panel SHALL treat Hermes `projects.json` (via CLI) as the only schedule source and SHALL NOT display or require Feishu calendar sync status for learning operations.

#### Scenario: Mutation success without calendar fields
- **WHEN** the user completes, moves, or edits deadline from the panel
- **AND** Hermes returns success
- **THEN** the panel shows only learning-specific notices (repack count, overflow, etc.)

### Requirement: Learning panel empty state directs conversational project creation

When no learning projects exist, the learning desk panel SHALL direct the user to create projects through Feishu or Hermes conversation (URL or "帮我安排学习"), and SHALL NOT offer in-panel project creation controls.

#### Scenario: Empty project tab
- **WHEN** `status` returns no projects
- **THEN** the project tab shows guidance to send a learning URL or intake phrase to Hermes conversation
- **AND** does not show a create-project button

#### Scenario: Insert sheet without active projects
- **WHEN** the user opens insert-task sheet with no active projects
- **THEN** the sheet explains that new projects must be created via Hermes conversation first

### Requirement: Project status overview tab

The learning desk panel SHALL provide a read-only project overview tab that displays learning projects by invoking Hermes `schedule.py status` and SHALL NOT mutate `projects.json` directly from this tab except through documented Hermes CLI write subcommands.

#### Scenario: Lazy load project status
- **WHEN** the user switches to the project overview tab
- **THEN** MalDaze loads project status via `schedule.py status`
- **AND** displays each project with name, status, deadline, progress, and next pending task when present

#### Scenario: Jump to today from project row
- **WHEN** the user activates a project row outside write controls
- **THEN** MalDaze switches to the today tab and highlights the first pending task for that project when one exists

### Requirement: Edit active project deadline from project tab

MalDaze SHALL allow users to change an active project's deadline from the project overview tab by spawning `schedule.py set-deadline --project-id <id> --deadline <YYYY-MM-DD>` after explicit confirmation. By default Hermes SHALL repack incomplete project tasks.

#### Scenario: Edit deadline on active project
- **WHEN** the user changes the deadline for an active project and confirms
- **THEN** MalDaze runs `schedule.py set-deadline` with the project id and new deadline
- **AND** on success refreshes project status, today, and schedule data as needed

#### Scenario: Repack overflow feedback
- **WHEN** `set-deadline` succeeds with `overflow_count` greater than zero
- **THEN** the panel shows a visible notice that some tasks could not fit before the new deadline

### Requirement: Delete project from project tab

MalDaze SHALL allow users to delete an entire learning project from the project overview tab by spawning `schedule.py delete-project --project-id <id>` after explicit confirmation.

#### Scenario: Delete project with confirmation
- **WHEN** the user confirms deletion of a project from the project tab
- **THEN** MalDaze invokes `schedule.py delete-project` with `HERMES_HOME` set
- **AND** refreshes today, schedule, and project status on success
- **AND** does not mutate `projects.json` directly in Swift

