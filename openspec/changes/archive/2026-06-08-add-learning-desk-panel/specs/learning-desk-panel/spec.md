## ADDED Requirements

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
- **WHEN** `today` reports `study.total_minutes` greater than `study.budget`
- **THEN** the panel header shows the over-budget state with visible emphasis
- **AND** the task list remains interactive

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
