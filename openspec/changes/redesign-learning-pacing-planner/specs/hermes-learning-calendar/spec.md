## MODIFIED Requirements

### Requirement: Balanced dynamic cadence across each project window

Hermes planning and repack SHALL assign each ordered pending non-review study task an ideal date derived from remaining task count and eligible non-rest days through the project deadline using cumulative balanced targets. Ideal per-day task counts SHALL be distributed as evenly as possible across the **full** eligible window. Cadence SHALL be a hard contract: output schedules MUST honor ideal per-day counts unless the planner declares the input infeasible.

#### Scenario: One lesson per day when counts match days
- **WHEN** a project has 25 remaining study tasks and 25 eligible study days through its deadline
- **THEN** each eligible day has exactly one ideal study task date
- **AND** ideal dates span the window through the deadline rather than clustering in the earliest days

#### Scenario: Multiple lessons per day when required by the window
- **WHEN** a project has 60 remaining study tasks and 20 eligible study days through its deadline
- **THEN** each eligible day has exactly three ideal study task dates
- **AND** Hermes does not impose a fixed one-task-per-project daily limit

#### Scenario: Spare days are distributed through a longer window
- **WHEN** a project has 19 remaining study tasks and 23 eligible study days through its deadline
- **THEN** ideal placement uses nineteen one-task days and four zero-task eligible days distributed through the window
- **AND** the first pending task ideal date is the first eligible day

#### Scenario: Cadence is not silently broken to satisfy capacity
- **WHEN** honoring all projects' ideal cadence dates would exceed shared `daily_capacity_minutes` on one or more days
- **THEN** Hermes returns `feasible: false`
- **AND** does not stack additional lessons on those days to force a schedule

### Requirement: Set project deadline and repack incomplete tasks

Hermes `schedule.py` SHALL provide a `set-deadline` subcommand that proposes the new deadline and, by default, globally reconciles incomplete tasks for all active projects from today using spine-based ideal dates, one shared study capacity, the separate review capacity, canonical task order, project deadlines, and configured rest days. When ideal placement cannot satisfy cadence, capacity, order, and deadlines together, Hermes SHALL return `feasible: false` and SHALL NOT persist a compromised schedule; the user MUST extend a deadline, increase capacity, or reduce scope before apply can succeed.

#### Scenario: Active project deadline update with global repack
- **WHEN** the user runs `schedule.py set-deadline --project-id <id> --deadline YYYY-MM-DD` for an active project without `--no-repack` and the merged ideal schedule is feasible
- **THEN** Hermes computes one candidate schedule for all active projects at ideal cadence dates
- **AND** a feasible apply persists the new deadline and all returned task-date changes atomically
- **AND** completed tasks and their dates remain unchanged

#### Scenario: Dry-run previews cross-project impact
- **WHEN** the user runs `schedule.py set-deadline --dry-run`
- **THEN** Hermes returns `repack_scope`, `feasible`, `affected_project_ids[]`, `project_cadences[]`, `changes[]` containing `project_id`, and conflict arrays when infeasible
- **AND** does not modify `projects.json`

#### Scenario: Capacity conflict makes repack infeasible
- **WHEN** ideal cadence dates for multiple active projects place more study minutes on a day than `daily_capacity_minutes`
- **THEN** Hermes returns `feasible: false` with `capacity_conflicts[]` identifying the date, load, capacity, and contributing projects/tasks
- **AND** non-dry-run exits non-zero without changing any deadline or task date

#### Scenario: User must extend deadline to resolve infeasibility
- **WHEN** dry-run returns `feasible: false` because ideal dates do not fit under shared capacity and deadlines
- **THEN** Hermes response includes human-actionable remedy hints such as extending a project deadline
- **AND** apply remains blocked until a subsequent feasible dry-run for the updated inputs

#### Scenario: Apply matches dry-run for the same snapshot
- **WHEN** the projects and profile snapshots do not change between a feasible dry-run and apply with equivalent arguments
- **THEN** apply persists the same deadline and task-date changes shown by dry-run

#### Scenario: Infeasible deadline preserves persisted schedule
- **WHEN** one or more ordered tasks cannot fit by project deadlines under the shared capacity at ideal cadence dates
- **THEN** Hermes returns `feasible: false` with structured conflict and overflow facts
- **AND** non-dry-run exits non-zero without changing the deadline or any task date

#### Scenario: No-repack compatibility flag
- **WHEN** the user runs `set-deadline --no-repack`
- **THEN** Hermes changes only the target project deadline
- **AND** does not run global reconciliation or modify task dates

### Requirement: Plan respects existing cross-project day load

When `schedule.py plan` places tasks for a new or empty project, Hermes SHALL build ideal cadence dates across the project's eligible deadline window, merge them against minutes already scheduled by all other projects, and SHALL declare the plan infeasible for candidates that cannot be placed at ideal dates without exceeding shared capacity. Hermes SHALL NOT move other projects' persisted tasks and SHALL NOT fill earliest days beyond ideal cadence to force placement.

#### Scenario: Plan avoids overfilling days with other projects
- **WHEN** another project already has pending tasks totaling 218 minutes on a day with 300-minute capacity
- **THEN** `plan` places at most 82 minutes of new-project ideal-dated tasks on that day
- **AND** returns infeasible overflow for candidates that cannot fit at ideal dates within the deadline

#### Scenario: Plan derives a multi-lesson cadence
- **WHEN** a new project has 60 study tasks and 20 eligible study days
- **THEN** `plan` targets three ordered ideal task dates per eligible day
- **AND** does not compress those tasks into fewer earlier days when capacity allows earlier stacking
