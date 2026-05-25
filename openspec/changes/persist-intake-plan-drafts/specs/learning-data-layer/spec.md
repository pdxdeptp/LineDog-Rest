## MODIFIED Requirements

### Requirement: SQLite 数据库初始化
The learning data layer SHALL use the learning preference default capacity consistently when initializing learning assistant runtime state.

#### Scenario: 首次启动初始化
- **WHEN** the backend starts and the database file does not exist
- **THEN** the system creates the required learning assistant runtime tables
- **AND** it writes default `system_state`: `load_mode=normal`, `daily_capacity_min=60`, `reduced_capacity_min=60`, `user_speed_factor=1.0`
- **AND** this `daily_capacity_min` default matches the learning preferences and material ingestion fallback defaults

## ADDED Requirements

### Requirement: Plan Draft Assumption Persistence
The learning data layer SHALL persist planning assumptions for drafts and activated plans.

#### Scenario: Draft assumptions are saved
- **WHEN** the system creates a deadline-driven draft
- **THEN** it records deadline, available time, target output, target depth, buffer policy, rest-day assumptions, source roles, schema version, draft version, and whether assumptions were accepted or user-edited
- **AND** draft tasks remain separate from active tasks until activation

#### Scenario: Activated plan preserves assumptions
- **WHEN** the user activates a draft
- **THEN** the activated plan retains its planning assumptions for later review and adjustment explanation
- **AND** Today and Calendar facts are derived only from the confirmed active task set

#### Scenario: Draft version increments after meaningful edit
- **WHEN** the user changes anchors, task estimates, scope, target output, target depth, archetype, or schedule-affecting settings
- **THEN** the system records a new draft version
- **AND** previous draft versions remain recoverable until activation or discard

### Requirement: Draft And Active State Separation
The learning data layer SHALL keep draft plan state separate from active plan state.

#### Scenario: Draft tasks are queried
- **WHEN** the user reviews a draft
- **THEN** the system returns draft tasks and draft schedule facts
- **AND** those tasks do not appear in active Today queries

#### Scenario: Draft is activated
- **WHEN** the user confirms a draft
- **THEN** the system creates or promotes active scheduled tasks
- **AND** the activation event records the intake item, assumptions, and generated schedule version

#### Scenario: Stale draft activation is rejected
- **WHEN** activation references a draft version that is not the latest activatable version
- **THEN** the system rejects activation
- **AND** no active task rows are created from the stale version

#### Scenario: Draft is discarded
- **WHEN** the user discards a draft
- **THEN** the system removes or marks draft tasks inactive
- **AND** no active plan facts change

### Requirement: Fallback Progress Persistence
The learning data layer SHALL persist low-energy fallback completion separately from full task completion.

#### Scenario: Fallback completion is recorded
- **WHEN** the user completes only fallback mode for a scheduled task
- **THEN** the system records fallback completion timestamp and actual minutes when available
- **AND** the task remains incomplete for full-progress and Today completion purposes

#### Scenario: Remaining work stays visible
- **WHEN** a task has fallback completion but not full completion
- **THEN** the task can be marked `needs_followup`
- **AND** rollover or adjustment logic can continue to account for the remaining work
