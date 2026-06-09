## ADDED Requirements

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
