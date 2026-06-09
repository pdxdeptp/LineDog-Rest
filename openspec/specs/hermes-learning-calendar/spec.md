# hermes-learning-calendar Specification

## Purpose

Learning tasks remain SSOT in `projects.json`. Hermes `schedule.py` does not project learning tasks to Feishu or any external calendar. Users create projects via Feishu/Hermes conversation; MalDaze desk panel is read/write for existing projects only.
## Requirements
### Requirement: Learning task SSOT remains projects.json

Learning tasks SHALL remain authoritative in `~/.hermes/data/learning-assistant/projects.json`. Hermes SHALL NOT project learning tasks to Feishu calendar or any external calendar as part of `schedule.py`.

#### Scenario: Complete updates JSON only
- **WHEN** Hermes completes learning task `task_3`
- **THEN** `projects.json` records `status: completed` for that task
- **AND** `schedule.py` does not call external calendar APIs

### Requirement: Local JSON files retain full learning history

Hermes SHALL treat `projects.json` and `daily_log.json` as the durable history SSOT. Completing a task SHALL NOT purge historical task records needed for later review.

#### Scenario: History survives completion
- **WHEN** a task is completed
- **THEN** the task remains queryable in `projects.json` with completed status
- **AND** the completion remains recorded in `daily_log.json` for that date

### Requirement: Completion interaction via conversation or desk panel

Users SHALL complete learning tasks through Feishu or Hermes conversation using `schedule.py complete`, or through the MalDaze learning desk panel spawning the same command.

#### Scenario: Today list then complete by id in Feishu
- **WHEN** the user asks for today's learning tasks in Feishu
- **THEN** Hermes lists pending tasks with identifiable task ids
- **AND** the user can complete a task by referring to that id in the same conversation

#### Scenario: Complete from MalDaze desk panel
- **WHEN** the user completes a task from the MalDaze learning desk panel
- **THEN** MalDaze invokes `schedule.py complete --task-id <id>` with `HERMES_HOME` set
- **AND** `projects.json` records `status: completed` for that task

### Requirement: Learning tasks are not migrated to Apple Reminders

Hermes SHALL NOT migrate learning tasks into Apple Reminders as a replacement for `projects.json` task semantics including review chains, move, remove, and capacity scheduling.

#### Scenario: No learning-to-reminders migration
- **WHEN** a learning task is planned or completed
- **THEN** Hermes does not create a parallel Apple Reminder representing that learning task
- **AND** learning scheduling semantics remain in the learning assistant data model

### Requirement: Move dry-run preview for desk panel

Hermes `schedule.py move` SHALL support a dry-run mode that returns the planned `changes[]` cascade without persisting date updates, so MalDaze can show move preview before apply.

#### Scenario: Dry-run returns cascade only
- **WHEN** MalDaze invokes `schedule.py move --task-id <id> --new-date <date> --dry-run`
- **THEN** Hermes prints JSON containing `changes[]` for the target and cascaded same-project tasks
- **AND** `projects.json` scheduled dates remain unchanged

#### Scenario: Apply move after preview
- **WHEN** MalDaze invokes `move` without `--dry-run` after user confirmation
- **THEN** Hermes persists the same changes that dry-run previewed for equivalent inputs

### Requirement: Create project CLI for conversation intake

Hermes `schedule.py` SHALL provide a `create-project` subcommand that creates an active learning project entry in `projects.json` with `id`, `name`, `deadline`, optional `source_url`, and empty `tasks[]`, without requiring manual JSON editing.

#### Scenario: Create empty project shell
- **WHEN** Hermes invokes `create-project --id <id> --name <name> --deadline <YYYY-MM-DD>`
- **THEN** `projects.json` gains a new project with empty `tasks[]` and the given metadata
- **AND** duplicate `id` returns an error without mutating existing projects

### Requirement: Single confirmation for new project intake

For new project intake, Hermes SHALL treat the user's confirmation of the task list as the only required confirmation before invoking `create-project` followed by `plan`. Hermes SHALL NOT require `plan --dry-run` for new project creation.

#### Scenario: Task list confirm then plan
- **WHEN** the user confirms the decomposed task list in conversation
- **THEN** Hermes runs `create-project` then `plan --project-id <id> --tasks-file <file>`
- **AND** reports `scheduled` / `overflow` from the plan result without a second create confirmation

### Requirement: Schedule range CLI for desk panel agenda

Hermes `schedule.py` SHALL provide a `schedule-range` subcommand that returns per-day incomplete learning tasks and capacity summaries from `projects.json` for a requested date range, without reading Feishu calendar.

#### Scenario: Default month range
- **WHEN** the user runs `schedule.py schedule-range` without `--from` or `--to`
- **THEN** Hermes returns days from the first day of the current calendar month through the later of the month end or any active project's `deadline` within a bounded maximum span
- **AND** each day includes `date`, `is_rest_day`, study and review minutes, budgets, `over_capacity`, and a `tasks` array

#### Scenario: Explicit from and to
- **WHEN** the user runs `schedule.py schedule-range --from YYYY-MM-DD --to YYYY-MM-DD`
- **THEN** Hermes returns one entry per calendar day in the inclusive range
- **AND** omits completed and failed tasks from each day's `tasks` list

#### Scenario: Month shortcut
- **WHEN** the user runs `schedule.py schedule-range --month YYYY-MM`
- **THEN** Hermes returns the same structure as an explicit from/to spanning that calendar month
- **AND** extends `to` through active project deadlines when later than month end, subject to the same maximum span cap

#### Scenario: Task fields for panel rendering
- **WHEN** a task is included in a day's `tasks` list
- **THEN** each task entry includes `task_id`, `project_id`, `project_name`, `title`, `duration_minutes`, `task_type`, `status`, and `after_project_deadline` indicating whether `scheduled_date` is after that project's deadline

#### Scenario: Over capacity matches validate discipline
- **WHEN** a day's study minutes exceed `daily_capacity_minutes` or review minutes exceed `review_budget_minutes`
- **THEN** that day's `over_capacity` is true
- **AND** the computation uses the same profile rest-day rules as `week-load` and `validate`

#### Scenario: MalDaze invokes schedule-range
- **WHEN** the MalDaze learning desk panel Schedule tab loads or changes month
- **THEN** MalDaze invokes `schedule.py schedule-range` with `HERMES_HOME` set
- **AND** does not aggregate `projects.json` locally in Swift

### Requirement: Set project deadline and repack incomplete tasks

Hermes `schedule.py` SHALL provide a `set-deadline` subcommand that updates the `deadline` of an active project and, by default, repacks that project's incomplete tasks into available schedule days from today through the new deadline using the same sequential day-capacity discipline as `plan`.

#### Scenario: Active project deadline update with repack
- **WHEN** the user runs `schedule.py set-deadline --project-id <id> --deadline YYYY-MM-DD` for an active project without `--no-repack`
- **THEN** Hermes persists the new deadline in `projects.json`
- **AND** reassigns `scheduled_date` for each incomplete task in project task-list order
- **AND** leaves completed tasks unchanged

#### Scenario: Dry-run preview
- **WHEN** the user runs `schedule.py set-deadline --dry-run`
- **THEN** Hermes returns preview fields including `changes[]`
- **AND** does not modify `projects.json`

### Requirement: Delete project CLI

Hermes `schedule.py` SHALL provide a `delete-project` subcommand that removes a project entry and all its tasks from `projects.json`.

#### Scenario: Delete existing project
- **WHEN** Hermes invokes `delete-project --project-id <id>` for an existing project
- **THEN** the project and all its tasks are removed from `projects.json`
- **AND** stdout JSON includes `action: delete-project` and `tasks_removed`

#### Scenario: Unknown project rejected
- **WHEN** `delete-project` is invoked for a non-existent project id
- **THEN** Hermes exits with an error
- **AND** does not modify other projects

### Requirement: Plan respects existing cross-project day load

When `schedule.py plan` places tasks for a new or empty project, Hermes SHALL subtract minutes already scheduled on each day from **all other projects** before applying `daily_capacity_minutes`.

#### Scenario: Plan avoids overfilling days with other projects
- **WHEN** another project already has pending tasks totaling 218 minutes on a day with 300-minute capacity
- **THEN** `plan` places at most 82 minutes of new-project tasks on that day before spilling to the next available day

