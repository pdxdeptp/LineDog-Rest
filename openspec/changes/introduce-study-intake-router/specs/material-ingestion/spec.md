## MODIFIED Requirements

### Requirement: 归一化资料结构
All handlers SHALL distinguish preview metadata from confirmed legacy resource structures so Add / Initiate can inspect sources without forcing every source into scheduled units.

#### Scenario: Intake preview does not require complete units
- **WHEN** Add / Initiate requests a source preview for routing or planning context
- **THEN** material ingestion may return title, source type, URL, shallow outline, estimated size, and role signals without a complete `units` list
- **AND** the preview does not write resources, units, or tasks

#### Scenario: Confirmed legacy ingestion still returns ResourceStructure
- **WHEN** the legacy URL ingestion path is used to create a schedulable resource
- **THEN** handlers still return a complete `ResourceStructure` with units and estimated hours before confirmation
- **AND** this compatibility path remains separate from intake preview role routing

### Requirement: GitHub 结构提取
GitHub ingestion SHALL use available README and directory facts for preview or confirmed resource structure, but SHALL NOT fabricate repository structure from only the repository name during Add / Initiate preview.

#### Scenario: Intake preview lacks structure
- **WHEN** README and directory tree do not provide reliable structure and the request is an Add / Initiate preview
- **THEN** ingestion leaves structure fields unknown and marks the preview low-calibration
- **AND** it does not generate learning units from only the repo name

#### Scenario: Legacy fallback is labeled synthetic
- **WHEN** the legacy confirmed URL-ingestion compatibility path needs a fallback unit after README and directory extraction fail
- **THEN** any generated placeholder unit is marked synthetic or low-calibration
- **AND** the placeholder is not treated as parsed repository fact by the Plan Compiler

## ADDED Requirements

### Requirement: Intake-Aware Material Analysis
Material ingestion SHALL act as an analysis helper for intake and SHALL NOT assume every parsed URL must become scheduled work.

#### Scenario: Intake requests material preview
- **WHEN** intake receives a URL, GitHub repo, PDF, video, or web page
- **THEN** material ingestion may return title, source type, URL, rough structure, estimated size, and suggested role signals
- **AND** it does not write active resources, units, or tasks during preview

#### Scenario: Parsed material is material-only attachment
- **WHEN** the user confirms that a parsed source is material-only support for an existing plan
- **THEN** material ingestion stores or attaches the material as support
- **AND** it does not create scheduled tasks unless the user explicitly confirms scheduled work

#### Scenario: Parsed material is reference or later resource
- **WHEN** the user confirms that a parsed source is reference material or later reading
- **THEN** material ingestion records the source with that role
- **AND** the source is excluded from Today and active plan scheduling

### Requirement: GitHub Role Metadata
GitHub ingestion SHALL provide shallow metadata that helps intake distinguish repository roles.

#### Scenario: GitHub repo preview succeeds
- **WHEN** the system can access the submitted GitHub repo
- **THEN** ingestion returns available title, description, README outline, topics, coarse directory signals, and a canonical repo role signal when available
- **AND** intake uses those signals to propose whether the repo is `main_learning_object`, `reference_source`, `clone_rebuild_target`, `project_material`, or `later_reading`

#### Scenario: GitHub repo preview fails
- **WHEN** the system cannot access the GitHub repo or shallow metadata is insufficient
- **THEN** ingestion returns a user-visible low-calibration preview state
- **AND** intake can continue with user-provided description instead of failing the whole flow
