# study-plan-adjustment Specification

## Purpose
TBD - created by archiving change introduce-study-plan-adjustment. Update Purpose after archive.
## Requirements
### Requirement: Unfinished Task Rollover
The system SHALL move incomplete active study tasks scheduled before the current local day into the current local day without cascading other project tasks.

#### Scenario: Unfinished task rolls into today
- **WHEN** an active study task was scheduled before today
- **AND** the task is not completed
- **THEN** the system moves that task to today's date before returning active study-plan facts
- **AND** it does not move later tasks in the same project
- **AND** it records the number of auto-rolled days for that task

#### Scenario: Rollover is idempotent
- **WHEN** rollover is evaluated multiple times on the same local day
- **THEN** the task remains scheduled today
- **AND** the auto-roll count is not double-incremented for the same elapsed day
- **AND** duplicate rollover events are not recorded for the same task/day

#### Scenario: Completion clears rollover badge state
- **WHEN** a rolled task is completed
- **THEN** the task completion remains persisted
- **AND** the task no longer appears as an active rolled task

### Requirement: Rolled Task Badge
The system SHALL expose rolled-task counts so the UI can show a badge when a task has auto-rolled at least three days.

#### Scenario: Badge appears at threshold
- **WHEN** an active task has auto-rolled three or more accumulated days
- **THEN** the Today view payload includes the rolled-day count for that task
- **AND** the UI displays a concise "rolled N days" badge for that task

#### Scenario: User-initiated movement resets rolled baseline
- **WHEN** the user moves a task, applies a dialogue movement, or a rest-day cascade moves that task
- **THEN** the task's auto-roll count is reset
- **AND** future missed days are counted from the new user-owned schedule baseline

### Requirement: Manual Task Date Move Cascade
The system SHALL let the user move an active unfinished task to another date and SHALL cascade the same date delta to unfinished later tasks in the same project only.

#### Scenario: Moving a task cascades later project tasks
- **WHEN** the user moves an active unfinished task from date A to date B
- **THEN** the selected task is scheduled on date B
- **AND** each unfinished same-project task after the selected task is shifted by the same delta `B - A`
- **AND** tasks in other projects are not moved
- **AND** completed tasks are not moved

#### Scenario: Move cannot target the past
- **WHEN** the user attempts to move a task before the current local day
- **THEN** the system rejects the move
- **AND** no task dates are changed

#### Scenario: Move records mechanical adjustment evidence
- **WHEN** a move succeeds
- **THEN** the system records an event with the selected task, affected task ids, original dates, new dates, and source `manual_move`

### Requirement: Project Deadline Editing
The system SHALL let the user edit an active study project's deadline without silently rescheduling tasks.

#### Scenario: Deadline edit updates project facts only
- **WHEN** the user changes an active project deadline
- **THEN** the resource deadline is updated
- **AND** existing task scheduled dates remain unchanged
- **AND** expected-late state is recalculated from current task facts

#### Scenario: Deadline cannot be removed
- **WHEN** the user attempts to clear the deadline for an active study project
- **THEN** the system rejects the edit
- **AND** explains that v2 active plans require deadlines for late-state detection

### Requirement: Red State Facts
The system SHALL expose expected-late and over-capacity states as factual status derived from active plan data.

#### Scenario: Project becomes expected late
- **WHEN** any active unfinished task in a study project is scheduled after that project's deadline
- **THEN** the project overview marks the project as expected late
- **AND** the system does not move tasks to hide the late state

#### Scenario: Day becomes over capacity
- **WHEN** active study task target minutes on a day exceed the configured daily capacity
- **THEN** Calendar marks that day over capacity
- **AND** the system does not move tasks to hide the overload

#### Scenario: Red state recalculates after every adjustment
- **WHEN** rollover, manual move, deadline edit, task add, task delete, dialogue apply, or rest-day cascade changes plan facts
- **THEN** Today, Project Overview, and Calendar refresh from persisted facts
- **AND** red states reflect the new facts

### Requirement: Manual Task Insertion
The system SHALL let the user add a new unfinished task to an active study project by providing title, target minutes, and scheduled date.

#### Scenario: User inserts a task on a date
- **WHEN** the user adds a task with title, target minutes, project, and scheduled date
- **THEN** the task is created on that date
- **AND** existing tasks are not moved
- **AND** project order can be derived from scheduled date and project task order facts

#### Scenario: Inserted task may create red state
- **WHEN** the inserted task pushes a day over capacity or lands after the project deadline
- **THEN** the relevant over-capacity or expected-late state is shown
- **AND** the system does not repair the plan automatically

### Requirement: Manual Task Deletion
The system SHALL let the user delete an unfinished active study task without cascading later tasks.

#### Scenario: User deletes one unfinished task
- **WHEN** the user deletes an unfinished active task
- **THEN** only that task is removed from active scheduling
- **AND** later same-project tasks keep their existing dates
- **AND** the day load becomes lighter from the deleted task

#### Scenario: Deleting the last unfinished task completes project history
- **WHEN** deletion leaves an active study project with no unfinished tasks
- **THEN** the project is marked completed
- **AND** it disappears from active views
- **AND** it appears in completed history

#### Scenario: Completed history is read-only
- **WHEN** a project is completed
- **THEN** the user cannot add, delete, move, or edit tasks in that completed project through this capability

### Requirement: Rest Day Settings
The system SHALL let the user define weekly and one-off rest days, where rest days have zero learning capacity.

#### Scenario: Rest days are excluded from future automatic placement
- **WHEN** a day is configured as a rest day
- **THEN** future generated or cascaded schedules treat that day as zero-capacity
- **AND** Calendar can show the day as a rest day

#### Scenario: Adding a rest day cascades future tasks
- **WHEN** the user adds a weekly rest weekday or one-off rest date
- **THEN** each affected future occurrence shifts unfinished active study tasks on and after that date by one day
- **AND** multiple newly added rest days are applied in chronological order
- **AND** the system records affected task ids and date deltas

#### Scenario: Removing a rest day does not cascade
- **WHEN** the user removes a weekly rest weekday or one-off rest date
- **THEN** existing active tasks keep their dates
- **AND** the removed day becomes available for future user moves or future generated plans

### Requirement: Dialogue Adjustment Preview And Apply
The system SHALL support bounded natural-language plan adjustments through a preview-plus-apply flow.

#### Scenario: User requests a supported project shift
- **WHEN** the user enters a supported instruction such as "push this project by one week"
- **THEN** the system returns a structured preview of affected tasks, old dates, new dates, and red-state impact
- **AND** no task dates are changed before the user applies the preview

#### Scenario: User applies a preview
- **WHEN** the user applies a dialogue adjustment preview
- **THEN** the system writes exactly the previewed changes
- **AND** records an event with source `dialogue_apply`
- **AND** refreshes active study views from persisted facts

#### Scenario: Unsupported dialogue instruction is safe
- **WHEN** the user enters an unsupported or ambiguous instruction
- **THEN** the system returns a clear no-op or clarification request
- **AND** does not mutate the active plan

### Requirement: Default Mode Silence
The system SHALL avoid generating assistant suggestions or automatic repairs in default mode during active plan adjustment.

#### Scenario: Manual adjustment creates red state
- **WHEN** a user adjustment creates expected-late or over-capacity state
- **THEN** the system displays the red state as fact
- **AND** it does not generate smart-mode suggestions in this capability
- **AND** it does not automatically apply a repair plan

