## ADDED Requirements

### Requirement: First-Version Input Coverage
The system SHALL support a bounded first-version set of manually submitted learning and project items.

#### Scenario: Supported first-version item types
- **WHEN** the user submits text goals, standard URLs, GitHub repo URLs, pasted note snippets, existing project descriptions, interview prep items, or resume/project material notes
- **THEN** the system accepts the input into the intake flow
- **AND** it routes the item before creating scheduled work

#### Scenario: Unsupported input falls back safely
- **WHEN** the system cannot parse or classify an input type with confidence
- **THEN** it allows manual title and description entry
- **AND** it marks any resulting plan intent as low-calibration or stores the item without active tasks

### Requirement: Intake Item Role Routing
The system SHALL route every submitted learning or project item into a proposed role before creating scheduled work.

#### Scenario: Route result has stable contract
- **WHEN** the router accepts an intake submission
- **THEN** it returns an intake item id, recommended role, confidence, reason codes, next action, and whether clarification is required
- **AND** the route result always states that no active tasks were created

#### Scenario: Intake submission is idempotent
- **WHEN** the client retries the same intake submission with the same client request id
- **THEN** the router returns the existing intake item and route result
- **AND** it does not create a second pending role confirmation or duplicate stored item

#### Scenario: Item is proposed as a new plan
- **WHEN** the user submits an item that expresses a goal needing deadline-driven execution
- **THEN** the system proposes the role `new_plan`
- **AND** the system does not create active daily tasks before the user confirms a plan draft

#### Scenario: Item is proposed as existing-plan work
- **WHEN** the user submits an item that appears to be a phase, task, or material for an existing active or draft plan
- **THEN** the system proposes `attach_to_existing_plan`
- **AND** it explains whether the item would be material-only, a draft phase, or scheduled work

#### Scenario: Item is proposed as non-executable material
- **WHEN** the user submits a reference, inspiration, or later resource
- **THEN** the system proposes `reference_material` or `later_resource`
- **AND** it stores the item without creating scheduled tasks

#### Scenario: Ambiguous role is clarified with one question
- **WHEN** the system cannot confidently choose between planning, attaching, storing, or one-off action
- **THEN** it asks one concise routing question with a recommended default
- **AND** it does not start a long questionnaire

### Requirement: Existing Plan Attachment Mode
The system SHALL represent existing-plan support as an attachment mode under `attach_to_existing_plan`.

#### Scenario: Existing plan support stores attachment mode
- **WHEN** an intake item is confirmed as belonging to an existing active or draft plan
- **THEN** the system records `attach_to_existing_plan` plus `material_only`, `draft_phase`, or `scheduled_work`
- **AND** user-facing supporting material is represented as `material_only` rather than a separate competing machine role

#### Scenario: Existing plan target is required for attachment
- **WHEN** the router recommends `attach_to_existing_plan` but no existing plan target is confirmed
- **THEN** it returns a target-selection or clarification next action
- **AND** it does not hand off to anchor review or scheduled work until both target plan and attachment mode are confirmed

#### Scenario: Material-only attachment does not alter schedule
- **WHEN** the user attaches an item to an existing plan as material only
- **THEN** the existing plan schedule remains unchanged
- **AND** no new active task is created

### Requirement: GitHub Repository Role Handling
The system SHALL treat GitHub repositories as first-class intake inputs with explicit roles.

#### Scenario: Repository can become a main learning object
- **WHEN** the user submits a GitHub repo as the main thing to learn
- **THEN** the system uses shallow repo metadata to help recommend role
- **AND** it records the repo role as `main_learning_object`

#### Scenario: Repository can be supporting or reference material
- **WHEN** the user submits a GitHub repo as reference, project material, clone/rebuild target, or later reading
- **THEN** the system records the canonical repo role as `reference_source`, `project_material`, `clone_rebuild_target`, or `later_reading`
- **AND** it does not automatically convert the repo into active daily tasks

#### Scenario: Repository role is separate from intake role
- **WHEN** a GitHub repo is routed
- **THEN** the system stores the intake role separately from the canonical repo role
- **AND** repo roles such as `clone_rebuild_target` or `project_material` do not replace machine roles such as `new_plan` or `attach_to_existing_plan`

#### Scenario: Repository fetch fails
- **WHEN** shallow repo metadata cannot be fetched
- **THEN** the system lets the user continue with manually supplied title or description
- **AND** any later generated draft is marked low-calibration

### Requirement: Add-Time Noise Boundaries
The system SHALL prevent submitted items from creating task noise before confirmation.

#### Scenario: One item creates one pending object
- **WHEN** the user submits one item
- **THEN** the system creates at most one visible pending role confirmation, draft intent, or stored-item confirmation for that submission
- **AND** it does not explode the input into multiple independent todos or alerts

#### Scenario: Supporting material does not create today action
- **WHEN** the user adds supporting material to an existing plan
- **THEN** the material is attached to the plan
- **AND** no new Today task is created unless the user explicitly adds or confirms scheduled work

#### Scenario: Immediate one-off requires explicit action
- **WHEN** the router proposes `immediate_one_off`
- **THEN** the system requires the user to explicitly create or schedule that one-off action
- **AND** it does not automatically add it to Today
