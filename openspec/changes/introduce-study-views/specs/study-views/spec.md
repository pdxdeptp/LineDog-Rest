## ADDED Requirements

### Requirement: Today Study View
The system SHALL provide a deterministic Today view that lists all active study tasks scheduled for the current local day across confirmed study projects.

#### Scenario: Today view lists active study tasks
- **WHEN** the user opens the learning assistant after at least one confirmed study project has tasks scheduled today
- **THEN** the Today view shows each active task scheduled for today
- **AND** each row shows the task title, project title, target minutes, completion state, and available learning link

#### Scenario: Today view excludes inactive project tasks
- **WHEN** a project is completed or archived out of the active plan
- **THEN** the Today view does not show unfinished future tasks from that inactive project

#### Scenario: Today view does not use generated assistant summaries
- **WHEN** the Today view is fetched
- **THEN** the system reads deterministic task and project facts
- **AND** it does not invoke a morning briefing agent or LLM to decide what tasks to show

### Requirement: Task Completion Updates Progress
The system SHALL let the user mark a Today task complete and SHALL update the corresponding project progress from task facts.

#### Scenario: User completes a task
- **WHEN** the user marks an active Today task complete
- **THEN** the task records `completed_at`
- **AND** its linked unit is marked complete when a linked unit exists
- **AND** the project's completed count and actual minutes are updated

#### Scenario: Completion refreshes views
- **WHEN** task completion succeeds
- **THEN** the Today view and Project Overview are refreshed from persisted facts
- **AND** stale pre-completion progress is not kept on screen

#### Scenario: Duplicate completion is safe
- **WHEN** the user or app repeats completion for an already completed task
- **THEN** the project progress is not double-counted
- **AND** no duplicate completion event is recorded for that task completion action

### Requirement: Project Overview
The system SHALL provide a Project Overview showing active study projects with progress and deadline facts.

#### Scenario: Active projects are summarized
- **WHEN** the user opens Project Overview
- **THEN** each active study project shows title, progress count, progress ratio, target or actual minutes, deadline, and status

#### Scenario: Project overview uses current task facts
- **WHEN** a project's task completion state changes
- **THEN** the overview recalculates progress from persisted task/unit facts
- **AND** it does not rely on stale cached resource card data

#### Scenario: Completed history is visible
- **WHEN** at least one study project has completed all tasks
- **THEN** Project Overview exposes a completed history section
- **AND** the completed project record remains available for later review

### Requirement: Calendar Load View
The system SHALL provide a read-only Calendar view that shows upcoming task distribution and load across the next several weeks.

#### Scenario: Calendar aggregates daily load
- **WHEN** the user opens Calendar view
- **THEN** the system shows a date-window of daily buckets
- **AND** each bucket includes scheduled task count, total target minutes, and completion count

#### Scenario: Calendar marks overloaded days
- **WHEN** a day's scheduled active task minutes exceed the configured daily capacity
- **THEN** that day is marked as over capacity
- **AND** the system does not automatically move tasks to hide the overload

#### Scenario: Calendar is read-only in this slice
- **WHEN** the user views tasks in Calendar view
- **THEN** the user can inspect distribution and load
- **AND** the user cannot drag, reschedule, add, or delete tasks from this slice's Calendar view

### Requirement: Automatic Completed Project Archive
The system SHALL remove a project from active views and preserve it in completed history when all of its tasks are complete.

#### Scenario: Last task completes a project
- **WHEN** the user completes the last unfinished task in an active study project
- **THEN** the project is marked as completed
- **AND** it no longer appears in active Today or active Project Overview sections
- **AND** it appears in completed project history

#### Scenario: Completed project records are preserved
- **WHEN** a project auto-completes
- **THEN** its resource, unit, task, and completion event records remain persisted
- **AND** the system does not hard-delete the project history

#### Scenario: Empty completed projects stay read-only
- **WHEN** a completed project appears in completed history
- **THEN** the user can review its completion facts
- **AND** this slice does not allow editing or adding tasks to that completed project
