## ADDED Requirements

### Requirement: Add Initiate User-Facing Language
学习助手中栏 SHALL present Add / Initiate choices, reasons, and anchors in user-facing language while preserving stable machine values internally.

#### Scenario: Entry uses outcome language
- **WHEN** the user opens Add / Initiate
- **THEN** the entry copy explains outcomes such as creating a plan, adding to an existing plan, saving material, or handling a one-off action
- **AND** it does not require understanding raw role ids

#### Scenario: Source type labels are localized
- **WHEN** the UI shows source type choices
- **THEN** each choice uses localized user-facing labels
- **AND** raw source type tokens are not shown as primary text

#### Scenario: Role review hides raw reason codes
- **WHEN** role review displays recommendation confidence or reasons
- **THEN** the UI summarizes them in user-facing wording
- **AND** raw reason codes are not shown as primary text

#### Scenario: Title can be reviewed
- **WHEN** the user confirms a role that may create or attach a plan draft
- **THEN** the UI allows the visible title to be reviewed or edited before handoff
- **AND** a long pasted body or URL is not silently used as the final title

### Requirement: Add Initiate Planning Anchor Inputs
学习助手中栏 SHALL collect planning anchors through controls that match user mental models and map to existing backend fields.

#### Scenario: Deadline is locally validated
- **WHEN** the user enters a deadline before generating a draft
- **THEN** the UI validates the date format locally
- **AND** invalid input shows guidance before submission

#### Scenario: Deadline type is explained
- **WHEN** the user chooses deadline type
- **THEN** the UI explains adjustable vs fixed deadline in user-facing terms

#### Scenario: Target depth uses meaningful choices
- **WHEN** the user chooses target depth
- **THEN** the UI offers meaningful labels such as quick orientation, usable skill, project output, interview-ready, or source understanding
- **AND** the selected label maps to the existing backend depth token before submission

#### Scenario: Assumptions are reviewable
- **WHEN** assumptions are present before draft generation
- **THEN** the UI shows them in an editable or explicitly accepted form
- **AND** the user does not need to restart the session to adjust them
