## MODIFIED Requirements

### Requirement: Set project deadline and repack incomplete tasks

Hermes `schedule.py` SHALL provide a `set-deadline` subcommand that updates the `deadline` of an active project and, by default, repacks that project's incomplete tasks into available schedule days from today through the new deadline using the same sequential day-capacity discipline as `plan`.

#### Scenario: Active project deadline update with repack
- **WHEN** the user runs `schedule.py set-deadline --project-id <id> --deadline YYYY-MM-DD` for an active project without `--no-repack`
- **THEN** Hermes persists the new deadline in `projects.json`
- **AND** reassigns `scheduled_date` for each incomplete task in project task-list order using available non-rest days and per-day study/review capacity
- **AND** leaves completed tasks unchanged
- **AND** prints JSON including `project_id`, `old_deadline`, `new_deadline`, `repacked`, `changes[]`, `overflow_count`, and `deadline_exceeded`

#### Scenario: Dry-run preview
- **WHEN** the user runs `schedule.py set-deadline --dry-run`
- **THEN** Hermes returns the same preview fields including `changes[]`
- **AND** does not modify `projects.json`

#### Scenario: No-repack compatibility flag
- **WHEN** the user runs `schedule.py set-deadline --no-repack`
- **THEN** Hermes updates only the project deadline
- **AND** does not change any task `scheduled_date`

#### Scenario: Overflow when deadline is too tight
- **WHEN** one or more incomplete tasks cannot be placed on or before the new deadline
- **THEN** those tasks remain listed in `overflow_tasks`
- **AND** `overflow_count` reflects the number of overflow tasks

#### Scenario: Reject non-active or unknown project
- **WHEN** the project id is unknown or the project status is not `active`
- **THEN** Hermes prints an `error` field and exits non-zero
- **AND** does not modify `projects.json`

#### Scenario: MalDaze invokes set-deadline with repack
- **WHEN** the user edits a project deadline from the MalDaze learning desk panel
- **THEN** MalDaze invokes `schedule.py set-deadline` with `HERMES_HOME` set
- **AND** does not write `projects.json` directly
