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

#### Scenario: Draft header links to intake item
- **WHEN** a plan-generating intake item enters draft persistence
- **THEN** the data layer records a draft header linked to the intake item id
- **AND** the draft header includes status, schema version, draft version, latest-version marker, calibration level, created time, and updated time

#### Scenario: Existing-plan draft records target
- **WHEN** a plan-generating intake item is for an existing plan phase or scheduled work
- **THEN** the draft header records the draft kind and target plan id
- **AND** the target plan id must reference an active plan at draft creation and again before activation

#### Scenario: Draft assumptions are saved
- **WHEN** the system creates a deadline-driven draft
- **THEN** it records deadline, available time, target output, target depth, buffer policy, rest-day assumptions, source roles, schema version, draft version, and whether assumptions were accepted or user-edited
- **AND** draft tasks remain separate from active tasks until activation

#### Scenario: Draft shell creation is idempotent
- **WHEN** the same intake item and draft kind are submitted to draft persistence more than once before activation
- **THEN** the data layer returns the existing draft shell
- **AND** it does not create duplicate draft headers or duplicate draft versions

#### Scenario: Assumption provenance is saved
- **WHEN** the system stores draft assumptions
- **THEN** each major planning fact records provenance as `user_provided`, `parsed`, `ai_assumed`, `system_default`, or `unknown`
- **AND** activatable draft versions preserve which assumptions were accepted or user-edited

#### Scenario: Activated plan preserves assumptions
- **WHEN** the user activates a draft
- **THEN** the activated plan retains its planning assumptions for later review and adjustment explanation
- **AND** Today and Calendar facts are derived only from the confirmed active task set

#### Scenario: Draft version increments after meaningful edit
- **WHEN** the user changes anchors, task estimates, scope, target output, target depth, archetype, or schedule-affecting settings
- **THEN** the system records a new draft version
- **AND** previous draft versions remain recoverable until activation or discard

#### Scenario: Non-meaningful edit does not create draft version
- **WHEN** the user changes display-only metadata that does not affect assumptions, phases, tasks, estimates, or schedule slices
- **THEN** the system may update the draft header without creating a new draft version
- **AND** activation eligibility remains tied to the latest meaningful draft version

### Requirement: Draft Persistence Migration Compatibility
The learning data layer SHALL migrate or extend existing draft storage without losing legacy draft data.

#### Scenario: Existing legacy draft tables are present
- **WHEN** the backend initializes with existing `study_project_drafts` or `study_project_draft_tasks` tables
- **THEN** the system adds the missing draft persistence contract fields or creates compatible companion tables idempotently
- **AND** existing draft rows remain available through the new logical draft query helpers

#### Scenario: Legacy draft status is mapped
- **WHEN** an existing draft row uses legacy status `review`
- **THEN** the system exposes it as a reviewable draft state compatible with the new lifecycle
- **AND** unrecoverable legacy assumptions are marked with `unknown` provenance

#### Scenario: Migration does not touch active work
- **WHEN** draft persistence migration runs
- **THEN** existing active resources, units, tasks, completion state, and Today facts are unchanged
- **AND** rerunning initialization does not duplicate draft versions or activation events

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

#### Scenario: Existing-plan draft activation uses target plan
- **WHEN** an existing-plan phase or scheduled-work draft is activated
- **THEN** active units or tasks are created under the recorded target plan
- **AND** no new top-level active resource is created for that draft

#### Scenario: Activation is transactional
- **WHEN** activation fails validation or active task creation fails
- **THEN** no active resource, unit, task, or activation event row remains partially written
- **AND** the draft remains reviewable with its prior status

#### Scenario: Duplicate activation is non-destructive
- **WHEN** activation is requested again for a draft version that already activated successfully
- **THEN** the system returns the existing activation event or rejects with an already-activated status
- **AND** it does not create duplicate active resources, units, or tasks

#### Scenario: Stale draft activation is rejected
- **WHEN** activation references a draft version that is not the latest activatable version
- **THEN** the system rejects activation
- **AND** no active task rows are created from the stale version

#### Scenario: Draft lacks activation-ready schedule
- **WHEN** activation is requested for a draft version without activation-ready task data and schedule slices
- **THEN** the system rejects activation before active task rows are inserted
- **AND** it does not attempt to generate dates during activation

#### Scenario: Draft is discarded
- **WHEN** the user discards a draft
- **THEN** the system removes or marks draft tasks inactive
- **AND** no active plan facts change

#### Scenario: Activated draft cannot be discarded as draft cleanup
- **WHEN** a caller attempts to discard a draft that already reached `active_plan`
- **THEN** the system rejects the discard request
- **AND** active plan rows remain unchanged

#### Scenario: Invalid lifecycle transition is rejected
- **WHEN** a caller attempts a draft lifecycle transition that is not allowed for the current status
- **THEN** the system rejects the transition
- **AND** no active task rows or activation events are created

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
