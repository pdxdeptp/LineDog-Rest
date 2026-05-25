## ADDED Requirements

### Requirement: Intake Item Persistence
The learning data layer SHALL persist submitted intake items separately from active scheduled tasks.

#### Scenario: Intake item is created
- **WHEN** the user submits a learning or project item
- **THEN** the system records the client request id, raw input, source type, created time, recommended role, confirmation state, and calibration level
- **AND** no active task row is created solely because the intake item exists

#### Scenario: Intake item creation is idempotent
- **WHEN** the same client request id is submitted more than once
- **THEN** the data layer returns the original intake item
- **AND** it does not create duplicate pending objects or duplicate non-plan resources

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

#### Scenario: Existing-plan attachment stores target and mode
- **WHEN** an intake item is confirmed as an existing-plan attachment
- **THEN** the data layer records the target plan id and attachment mode
- **AND** `material_only` attachments remain outside active scheduling

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
