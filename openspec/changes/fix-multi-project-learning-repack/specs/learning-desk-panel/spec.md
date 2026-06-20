## MODIFIED Requirements

### Requirement: Edit active project deadline from project tab

MalDaze SHALL allow users to change an active project's deadline from the project overview tab by invoking Hermes `schedule.py set-deadline --dry-run` before confirmation and applying the same command without `--dry-run` only after explicit confirmation. MalDaze SHALL disclose that Hermes may reconcile incomplete tasks across all active projects and SHALL NOT calculate dates, cadence, or capacity locally.

#### Scenario: Edit deadline previews global reconciliation
- **WHEN** the user selects a new deadline for an active project
- **THEN** MalDaze runs `set-deadline --dry-run` with the project id and proposed date
- **AND** shows feasibility, affected project count, per-project cadence summary, and moved-task count from the Hermes response

#### Scenario: Confirm feasible deadline apply
- **WHEN** the dry-run is feasible and the user confirms the disclosed cross-project changes
- **THEN** MalDaze runs `schedule.py set-deadline` with equivalent arguments
- **AND** on success refreshes project status, today, and schedule data from Hermes

#### Scenario: Infeasible preview blocks confirmation
- **WHEN** dry-run returns `feasible: false`
- **THEN** MalDaze shows Hermes-authored capacity/deadline conflict details
- **AND** does not enable apply for that proposed deadline

#### Scenario: Repack overflow feedback
- **WHEN** Hermes reports overflow or capacity conflicts
- **THEN** the panel visibly identifies affected projects and tasks
- **AND** does not hide, filter, or locally reschedule those tasks

#### Scenario: MalDaze remains a contract consumer
- **WHEN** deadline repack changes tasks in multiple projects
- **THEN** MalDaze renders the returned project ids and change facts
- **AND** never writes `projects.json` or computes replacement dates in Swift
