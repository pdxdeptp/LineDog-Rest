## ADDED Requirements

### Requirement: Add Initiate Draft Review Edit Honesty
学习助手中栏 SHALL make draft review edits truthful by ensuring visible saved edits affect the draft used for activation or are clearly marked as local/non-persistent.

#### Scenario: Visible saved edits affect activation
- **WHEN** the UI presents a draft item edit as saved
- **THEN** the edit creates or targets a current draft version used by activation
- **AND** stale draft versions are not activated with newer edits implied

#### Scenario: Non-persistent edits are labeled or removed
- **WHEN** a draft item field cannot be persisted into the activated plan
- **THEN** the UI does not present that field as a saved edit
- **AND** if shown, it is labeled as local-only or estimate-only

#### Scenario: Estimate edits request a new review
- **WHEN** the user changes estimates before activation
- **THEN** the UI applies the estimate changes through an option effect or draft edit path
- **AND** activation is offered only after the resulting review state is current

### Requirement: Add Initiate Infeasible Option Parameters
学习助手中栏 SHALL collect or visibly confirm required parameters before applying infeasible-review options.

#### Scenario: Extend deadline shows target date
- **WHEN** the user selects extend-deadline
- **THEN** the UI shows the deadline value that will be applied
- **AND** the option is not sent with an empty or hidden date parameter

#### Scenario: Increase capacity shows new capacity
- **WHEN** the user selects increase-capacity
- **THEN** the UI shows the daily capacity value that will be applied
- **AND** the option is not sent with an empty or hidden capacity parameter

#### Scenario: Lower depth shows selected depth
- **WHEN** the user selects lower-depth
- **THEN** the UI shows the requested target depth before applying

#### Scenario: Option effect returns review before activation
- **WHEN** an infeasible option is applied
- **THEN** the UI shows option-effect progress
- **AND** the result is displayed as a new review state, storage state, compiler-recompute handoff, or focused input state before activation is offered

#### Scenario: Hard deadline hides accept late finish
- **WHEN** a draft has hard deadline type
- **THEN** the UI does not display accept-late-finish as an available option

### Requirement: Add Initiate Draft Review Summary
学习助手中栏 SHALL preserve compact-first draft review while allowing full schedule and source inspection by explicit expansion.

#### Scenario: Summary appears before full schedule
- **WHEN** a draft review package is available
- **THEN** the UI first shows role, title, target output, target depth, key assumptions, first-week schedule, buffer, fallback, capacity risk, and deadline risk
- **AND** full schedule and source details remain behind explicit expansion controls
