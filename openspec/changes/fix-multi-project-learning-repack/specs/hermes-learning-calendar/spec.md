## ADDED Requirements

### Requirement: Balanced dynamic cadence across each project window

Hermes planning and repack SHALL derive each active project's preferred daily study-task count from its ordered remaining non-review tasks and eligible non-rest days through its deadline. Preferred daily counts SHALL be distributed as evenly as possible, while task durations and shared daily capacity remain hard constraints.

#### Scenario: One lesson per day when counts match days
- **WHEN** a project has 25 remaining study tasks and 25 eligible study days through its deadline
- **THEN** its preferred cadence is one ordered study task on each eligible day

#### Scenario: Multiple lessons per day when required by the window
- **WHEN** a project has 60 remaining study tasks and 20 eligible study days through its deadline
- **THEN** its preferred cadence is three ordered study tasks on each eligible day
- **AND** Hermes does not impose a fixed one-task-per-project daily limit

#### Scenario: Spare days are distributed through a longer window
- **WHEN** a project has 19 remaining study tasks and 23 eligible study days through its deadline
- **THEN** its preferred cadence contains nineteen one-task days and four zero-task days distributed through the window
- **AND** the first pending task is not needlessly delayed beyond the first eligible day

#### Scenario: Duration pressure overrides preferred task count
- **WHEN** the combined durations of preferred tasks do not fit the shared daily study capacity
- **THEN** Hermes shifts whole tasks while preserving project order and deadline urgency
- **AND** never exceeds `daily_capacity_minutes` to satisfy a preferred count

### Requirement: Global validation of active learning capacity

Hermes `schedule.py validate` SHALL aggregate pending study and review minutes across all active projects by date and SHALL use the same rest-day and capacity discipline as `schedule-range`.

#### Scenario: Individually valid projects are globally over capacity
- **WHEN** two active projects contain 281 and 240 study minutes on the same 300-minute day
- **THEN** `validate` reports a global `study_capacity_exceeded` issue for 521 minutes
- **AND** `schedule-range` reports `over_capacity: true` for the same date

#### Scenario: Aggregate schedule stays within capacity
- **WHEN** all active projects together use no more than the configured study and review budgets on every non-rest day
- **THEN** `validate` reports no capacity issue

## MODIFIED Requirements

### Requirement: Set project deadline and repack incomplete tasks

Hermes `schedule.py` SHALL provide a `set-deadline` subcommand that proposes the new deadline and, by default, globally reconciles incomplete tasks for all active projects from today. The reconciliation SHALL use balanced per-project cadence, one shared study capacity, the separate review capacity, canonical task order, project deadlines, and configured rest days.

#### Scenario: Active project deadline update with global repack
- **WHEN** the user runs `schedule.py set-deadline --project-id <id> --deadline YYYY-MM-DD` for an active project without `--no-repack`
- **THEN** Hermes computes one candidate schedule for all active projects
- **AND** a feasible apply persists the new deadline and all returned task-date changes atomically
- **AND** completed tasks and their dates remain unchanged

#### Scenario: Dry-run previews cross-project impact
- **WHEN** the user runs `schedule.py set-deadline --dry-run`
- **THEN** Hermes returns `repack_scope`, `feasible`, `affected_project_ids[]`, `project_cadences[]`, and `changes[]` containing `project_id`
- **AND** does not modify `projects.json`

#### Scenario: Apply matches dry-run for the same snapshot
- **WHEN** the projects and profile snapshots do not change between a feasible dry-run and apply with equivalent arguments
- **THEN** apply persists the same deadline and task-date changes shown by dry-run

#### Scenario: Infeasible deadline preserves persisted schedule
- **WHEN** one or more ordered tasks cannot fit by project deadlines under the shared capacity
- **THEN** Hermes returns `feasible: false` with structured conflict and overflow facts
- **AND** non-dry-run exits non-zero without changing the deadline or any task date

#### Scenario: No-repack compatibility flag
- **WHEN** the user runs `set-deadline --no-repack`
- **THEN** Hermes changes only the target project deadline
- **AND** does not run global reconciliation or modify task dates

### Requirement: Plan respects existing cross-project day load

When `schedule.py plan` places tasks for a new or empty project, Hermes SHALL calculate that project's balanced cadence across its eligible deadline window and subtract minutes already scheduled by all other projects before applying the shared `daily_capacity_minutes` limit.

#### Scenario: Plan avoids overfilling days with other projects
- **WHEN** another project already has pending tasks totaling 218 minutes on a day with 300-minute capacity
- **THEN** `plan` places at most 82 minutes of new-project tasks on that day
- **AND** shifts remaining preferred tasks without exceeding shared capacity

#### Scenario: Plan derives a multi-lesson cadence
- **WHEN** a new project has 60 study tasks and 20 eligible study days
- **THEN** `plan` begins from a preferred cadence of three ordered tasks per eligible day
- **AND** adjusts that cadence around occupied shared capacity rather than tightly filling the earliest days
