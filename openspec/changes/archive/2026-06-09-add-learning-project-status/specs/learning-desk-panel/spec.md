## ADDED Requirements

### Requirement: Project status overview tab

The learning desk panel SHALL provide a read-only project overview tab that displays learning projects by invoking Hermes `schedule.py status` and SHALL NOT mutate `projects.json` directly from this tab except through documented Hermes CLI write subcommands.

#### Scenario: Lazy load project status
- **WHEN** the user switches to the project overview tab
- **THEN** MalDaze loads project status via `schedule.py status` (or reuses a fresh in-memory status cache from a recent `loadToday` / `fetchStatus` when still valid)
- **AND** displays each project returned by status with name, project status, deadline when present, progress fraction and percent, and next pending task summary when present

#### Scenario: All projects with non-active de-emphasis
- **WHEN** status returns projects whose `status` is not `active`
- **THEN** the panel still lists those projects
- **AND** renders them with visually de-emphasized styling compared to active projects

#### Scenario: Project list ordering
- **WHEN** the project overview tab renders multiple projects
- **THEN** active projects appear before non-active projects
- **AND** within each group projects are sorted by name ascending

#### Scenario: Empty project list
- **WHEN** status returns an empty array
- **THEN** the panel shows a friendly empty state directing the user to plan via Feishu Hermes
- **AND** does not treat it as an error

#### Scenario: Next task semantics
- **WHEN** status includes `next_task` for a project
- **THEN** the panel displays that task as the queue's next pending item per Hermes status output
- **AND** does not imply it is sorted by scheduled date or limited to today's tasks

#### Scenario: Next task with duration
- **WHEN** `next_task` includes `duration_minutes`
- **THEN** the panel displays the duration alongside the task title and scheduled date when present

#### Scenario: No next task
- **WHEN** status reports a project with no `next_task`
- **THEN** the panel shows an explicit empty-next-task state for that project
- **AND** does not treat it as an error

#### Scenario: Deadline emphasis
- **WHEN** a project deadline is in the past
- **THEN** the panel visually emphasizes the overdue deadline
- **WHEN** a project deadline is within seven calendar days and not overdue
- **THEN** the panel visually emphasizes the approaching deadline

#### Scenario: Manual refresh on project tab
- **WHEN** the user taps refresh while the project overview tab is selected
- **THEN** MalDaze re-runs `schedule.py status`
- **AND** updates the displayed project list

#### Scenario: Status load failure
- **WHEN** `status` fails or returns unparseable output
- **THEN** the project tab shows an error message with remediation guidance
- **AND** other dashboard columns remain usable

#### Scenario: Jump to today from project row
- **WHEN** the user activates a project row area outside the deadline edit control
- **THEN** MalDaze switches to the today tab
- **AND** scrolls to and briefly highlights the first today pending task matching that `project_id` when one exists

### Requirement: Project status refresh after today mutations

After a successful write operation initiated from the learning panel (complete, move, insert, remove, review, or set-deadline), MalDaze SHALL invalidate or refresh cached project status so the project overview tab does not show stale progress or next-task data after the user switches tabs.

#### Scenario: Complete then switch to project tab
- **WHEN** the user completes a task on the today tab and later opens the project overview tab
- **THEN** MalDaze shows updated progress and next-task data without requiring a manual refresh

### Requirement: Project tab refresh on projects.json changes

When the project overview tab is visible, MalDaze SHALL refresh project status on debounced `projects.json` file events without running rollover.

#### Scenario: External edit while on project tab
- **WHEN** `projects.json` changes while the user is on the project overview tab
- **THEN** MalDaze refreshes status data within the debounce window
- **AND** does not run rollover solely due to the file event

## MODIFIED Requirements

### Requirement: Edit active project deadline from project tab

MalDaze SHALL allow users to change an active project's deadline from the project overview tab by spawning `schedule.py set-deadline --project-id <id> --deadline <YYYY-MM-DD>` after explicit confirmation. By default Hermes SHALL repack incomplete project tasks; MalDaze SHALL NOT compute repack dates locally in Swift.

#### Scenario: Edit deadline on active project
- **WHEN** the user changes the deadline for an active project and confirms
- **THEN** MalDaze runs `schedule.py set-deadline` with the project id and new deadline
- **AND** on success refreshes project status, today, and week-load data as needed
- **AND** does not mutate `projects.json` directly

#### Scenario: Deadline edit opens a single sheet
- **WHEN** the user activates the bordered deadline edit control on an active project
- **THEN** MalDaze opens one sheet with a calendar date picker and explicit cancel/confirm actions
- **AND** does not show a second confirmation layer while the user is still picking a date in the list

#### Scenario: Confirmation explains repack behavior
- **WHEN** the user is about to confirm a deadline change in the sheet
- **THEN** the panel states that incomplete tasks will be repacked from today through the new deadline
- **AND** states that completed tasks will not be moved

#### Scenario: Repack overflow feedback
- **WHEN** `set-deadline` succeeds with `overflow_count` greater than zero
- **THEN** the panel shows a visible notice that some tasks could not fit before the new deadline
- **AND** refreshes the displayed schedule data

#### Scenario: Non-active deadline is read-only
- **WHEN** a project status is not `active`
- **THEN** the panel shows its deadline without an edit control

#### Scenario: Deadline edit failure
- **WHEN** `set-deadline` returns an error
- **THEN** the panel shows the Hermes error message
- **AND** the previously displayed deadline remains until a successful retry
