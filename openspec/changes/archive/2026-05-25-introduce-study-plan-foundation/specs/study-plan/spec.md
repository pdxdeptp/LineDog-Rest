## ADDED Requirements

### Requirement: Daily Capacity Setting
The system SHALL allow the user to set a global daily learning time capacity in minutes, and SHALL use that capacity when generating draft study plans.

#### Scenario: Capacity is used for draft scheduling
- **WHEN** the user has set a daily learning capacity
- **AND** the system generates a draft study plan
- **THEN** the draft scheduler uses that capacity as the per-day target for placing task minutes

#### Scenario: Capacity can be changed before later drafts
- **WHEN** the user changes the daily learning capacity
- **THEN** future draft plans use the updated capacity
- **AND** already confirmed active plans are not silently regenerated

### Requirement: URL Study Project Intake
The system SHALL let the user start a study project by providing a URL and a required deadline.

#### Scenario: User starts a URL project
- **WHEN** the user submits a valid URL and deadline
- **THEN** the system begins the study-plan intake flow
- **AND** the system does not create active daily tasks yet

#### Scenario: Deadline is required
- **WHEN** the user attempts to start a URL project without a deadline
- **THEN** the system blocks project generation
- **AND** explains that the deadline is required for initial calendar placement and late-status detection

### Requirement: Guided Clarification Before Decomposition
The system SHALL present a skippable guided clarification step before decomposing a URL into a draft plan.

#### Scenario: Clarification questions are generated
- **WHEN** the system has previewed the submitted URL content
- **THEN** it presents at most three clarification questions covering current level or familiarity, learning goal and target depth, and focus or skip scope
- **AND** each question provides selectable recommendations
- **AND** each question allows the user to accept an uncertain or recommended default

#### Scenario: Material type shapes the final question
- **WHEN** the URL content is structure-oriented
- **THEN** the final clarification question emphasizes focus or skip scope

#### Scenario: Project output shapes the final question
- **WHEN** the URL content is project-oriented or output-oriented
- **THEN** the final clarification question emphasizes target output

#### Scenario: User skips clarification
- **WHEN** the user chooses to generate a rough plan directly
- **THEN** the system continues using recommended defaults
- **AND** the resulting draft plan is marked as low-calibration in review

### Requirement: Decomposition Pipeline
The system SHALL generate draft plan tasks through a multi-step decomposition pipeline rather than one single all-purpose generation step.

#### Scenario: Pipeline creates ordered draft tasks
- **WHEN** the user completes or skips guided clarification
- **THEN** the system extracts source structure
- **AND** estimates difficulty
- **AND** estimates task durations
- **AND** merges units into ordered draft tasks
- **AND** preserves project-internal order

#### Scenario: Unknown material type uses fallback
- **WHEN** the URL does not match a specialized material handler
- **THEN** the system uses a generic fallback handler
- **AND** still returns ordered draft tasks or a user-visible failure state

### Requirement: Initial Draft Scheduling
The system SHALL schedule draft tasks across non-rest days from today through the project deadline using a deterministic spread algorithm.

#### Scenario: Tasks are spread across non-rest days
- **WHEN** the system has ordered draft tasks and a deadline
- **THEN** it places tasks only on non-rest days within the inclusive date window from today through the deadline
- **AND** it spreads estimated minutes across available days using the configured daily capacity

#### Scenario: Existing project load does not reshuffle the draft
- **WHEN** other projects already have tasks on the same days
- **THEN** the new draft keeps its own deterministic placement
- **AND** overloaded days are marked as over capacity rather than silently repaired

#### Scenario: Tasks after deadline are marked
- **WHEN** draft task placement would land after the required deadline
- **THEN** the draft marks the project as expected to be late
- **AND** the system does not silently move unrelated tasks to hide the late state

### Requirement: Draft Review State
The system SHALL keep generated plans in a review state until the user confirms them.

#### Scenario: Draft is reviewable before activation
- **WHEN** URL decomposition and scheduling complete
- **THEN** the system shows a draft plan for review
- **AND** draft tasks are not included in the active daily task list

#### Scenario: User cancels draft
- **WHEN** the user cancels the draft plan
- **THEN** the system discards the draft
- **AND** no active project or daily task is created

### Requirement: Task Duration Editing During Review
The system SHALL let the user edit estimated task durations while reviewing a draft plan.

#### Scenario: User edits a duration
- **WHEN** the user changes a draft task duration
- **THEN** the draft stores the new duration
- **AND** review totals and capacity status are recalculated for the draft

#### Scenario: Duration edits do not activate the plan
- **WHEN** the user edits one or more draft durations
- **THEN** the plan remains in review state until the user confirms it

### Requirement: Confirm Draft Into Active Plan
The system SHALL activate a reviewed draft plan only after explicit user confirmation.

#### Scenario: User confirms draft
- **WHEN** the user confirms the reviewed draft plan
- **THEN** the system creates an active study project
- **AND** creates its ordered tasks with scheduled dates and target minutes
- **AND** makes those tasks eligible for daily use

#### Scenario: Confirmation records source and calibration
- **WHEN** the system activates a draft plan
- **THEN** it records the source URL, deadline, capacity assumptions, whether clarification was skipped, and the task duration estimates used for activation
