## MODIFIED Requirements

### Requirement: SQLite 数据库初始化
系统 SHALL use the learning preference default capacity consistently when initializing learning assistant runtime state.

#### Scenario: 首次启动初始化
- **WHEN** 后端启动且数据库文件不存在
- **THEN** 系统创建 `resources`、`units`、`tasks`、`plan_versions`、`events`、`system_state` 表
- **AND** 系统写入默认 `system_state`：`load_mode=normal`、`daily_capacity_min=60`、`reduced_capacity_min=60`、`user_speed_factor=1.0`
- **AND** this `daily_capacity_min` default matches the learning preferences and material ingestion fallback defaults

## ADDED Requirements

### Requirement: Intake Item Persistence
The learning data layer SHALL persist submitted intake items separately from active scheduled tasks.

#### Scenario: Intake item is created
- **WHEN** the user submits a learning or project item
- **THEN** the system records the raw input, source type, created time, recommended role, confirmation state, and calibration level
- **AND** no active task row is created solely because the intake item exists

#### Scenario: Intake item is cancelled
- **WHEN** the user cancels an intake item before activation
- **THEN** the data layer either discards it or stores it as later/reference according to the user's choice
- **AND** it remains excluded from active Today facts

### Requirement: Role-Based Learning Entities
The learning data layer SHALL distinguish planned projects, phases, executable tasks, supporting materials, reference materials, and later resources.

#### Scenario: Supporting material attaches to a plan
- **WHEN** the user attaches material to an active or draft plan as support
- **THEN** the system records the relationship between the material and the plan
- **AND** the material does not become executable work by default

#### Scenario: Existing-plan support stores attachment mode
- **WHEN** an intake item is confirmed as belonging to an existing active or draft plan
- **THEN** the data layer records `attach_to_existing_plan` plus an attachment mode such as `material_only`, `draft_phase`, or `scheduled_work`
- **AND** user-facing supporting material is represented as `material_only` rather than a separate competing machine role

#### Scenario: Reference material is stored
- **WHEN** the user stores an item as reference material
- **THEN** the system records it with a reference role
- **AND** it is not counted as active project progress or daily workload

#### Scenario: Later resource is stored
- **WHEN** the user stores an item for later
- **THEN** the system records it with a later/backlog role
- **AND** it is excluded from active scheduling, deadline risk, and Today views

#### Scenario: Only executable tasks are Today eligible
- **WHEN** the system computes Today facts
- **THEN** it includes confirmed executable tasks from active plans
- **AND** it excludes intake items, draft tasks, supporting materials, reference materials, and later resources

#### Scenario: Source can have multiple relationships
- **WHEN** a source is used by the system
- **THEN** it can be related to a plan as main object, supporting material, project material, reference, or later resource
- **AND** the relationship controls scheduling behavior rather than the source type alone

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
