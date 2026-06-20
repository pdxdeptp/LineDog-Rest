## ADDED Requirements

### Requirement: Today tab splits Hermes tasks and local todo with resizable divider

The learning desk panel today tab SHALL divide vertical space between the Hermes today task region (upper) and the MalDaze local today todo region (lower) using the same row resize handle chrome as the dashboard plan/nutrition split. The upper/lower height ratio SHALL persist in app settings, and todo layout SHALL derive its current content capacity from the lower region's live content-area geometry.

#### Scenario: Drag divider adjusts regions
- **WHEN** the user drags the resize handle between Hermes tasks and today todo
- **THEN** MalDaze updates the live upper and lower heights on every drag update
- **AND** persists the final ratio when the drag ends

#### Scenario: Todo layout reacts to vertical geometry immediately
- **WHEN** the todo content-area height changes because of divider drag or vertical dashboard resize
- **THEN** the today todo section resolves its viewport from the current content-area height without waiting for a new content measurement
- **AND** does not use whole-tab height, a fixed dashboard fraction, a previous outer section-height snapshot, or parent drag-state freezing

#### Scenario: Horizontal resize remeasures wrapped content
- **WHEN** horizontal dashboard resize changes the todo content width enough to invalidate the measured list width by more than 0.5pt
- **THEN** the today todo section enters its safe measuring layout
- **AND** applies compact or pinned layout when the next complete list-and-draft measurement snapshot arrives
- **AND** does not require another user action

#### Scenario: Draft remains visible during supported divider drag
- **WHEN** divider movement crosses the compact/pinned boundary while the todo content area can contain the measured draft row and spacing
- **THEN** the draft input remains fully within the visible todo content area
- **AND** the correct mode is applied without additional drag distance or another user event
- **AND** a transition into pinned uses the same bottom-anchor behavior as any other pinned transition

#### Scenario: Todo content area is physically too short
- **WHEN** the todo content area is shorter than the measured draft row plus spacing
- **THEN** MalDaze clamps the list viewport to zero and prioritizes the single draft row in the remaining area
- **AND** does not create a negative frame, move the draft into the list, or modify the persisted split ratio
- **AND** automatically restores normal layout when sufficient height returns

#### Scenario: Hermes failure still shows todo region
- **WHEN** Hermes today load fails
- **THEN** the lower today todo region remains visible and interactive when local JSON is readable
- **AND** the resize handle remains usable between the error or loading upper region and the todo region
