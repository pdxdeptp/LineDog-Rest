## ADDED Requirements

### Requirement: Add Initiate Async Feedback And Recovery
The system SHALL expose stage-level progress and recovery paths during routing, preview, compilation, scheduling, and activation.

#### Scenario: Progress stages are visible
- **WHEN** Add / Initiate processing is running
- **THEN** the UI can show stages such as analyzing input, routing item, previewing source, generating phases, generating tasks, validating tasks, scheduling, and preparing review

#### Scenario: Preview or generation failure is recoverable
- **WHEN** material preview, LLM generation, validation, or scheduling cannot complete normally
- **THEN** the user can retry, simplify input, answer one question, continue manually when safe, store for later, or cancel

#### Scenario: Activation failure preserves draft
- **WHEN** plan activation fails
- **THEN** the current draft version remains intact
- **AND** the user can retry activation without recreating the plan from scratch

### Requirement: Draft Review And Activation
The system SHALL keep generated plans in draft review until the user explicitly activates them.

#### Scenario: Draft is reviewable
- **WHEN** a plan draft is generated
- **THEN** the user can review role, assumptions, deadline, target output, target depth, phases, daily schedule, buffer, and risk states
- **AND** the draft does not affect Today or active Calendar views

#### Scenario: Draft review is summary-first
- **WHEN** the user first sees a plan draft
- **THEN** the system shows a compact summary of role, deadline fit, assumptions, first-week schedule, buffer, and risk
- **AND** full schedule details, source details, and per-task edits are available behind explicit expansion controls

#### Scenario: User confirms draft
- **WHEN** the user activates a reviewed draft
- **THEN** the system creates an active plan with scheduled tasks
- **AND** those tasks become eligible for Today, Calendar, adjustment, and smart-mode proposal flows

#### Scenario: User cancels draft
- **WHEN** the user cancels a draft
- **THEN** the system does not create active tasks
- **AND** the user may discard the intake item or keep it as later material

### Requirement: Add-Time Noise Boundaries
The system SHALL prevent submitted items from creating task noise before confirmation.

#### Scenario: Draft does not create today action
- **WHEN** a generated plan is still in draft review
- **THEN** no task from that draft appears in Today
- **AND** no smart suggestion is triggered from that draft

#### Scenario: Confirmed plans drive Today
- **WHEN** the user opens Today
- **THEN** Today contains tasks from confirmed active plans only
- **AND** it excludes references, later resources, and unconfirmed drafts
