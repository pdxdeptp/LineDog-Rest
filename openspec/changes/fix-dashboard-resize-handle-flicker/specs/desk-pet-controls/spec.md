## ADDED Requirements

### Requirement: Dashboard resize separator drag stability
Dashboard resize separators SHALL compute drag deltas from a coordinate space that remains stable while the separator view moves during live layout updates.

#### Scenario: Column resize drag remains smooth
- **WHEN** the user drags either Dashboard column separator horizontally
- **THEN** the adjacent column width updates without oscillating or flickering due to the separator view's own movement
- **AND** the separator continues to show the horizontal resize cursor while draggable

#### Scenario: Plan and nutrition resize drag remains smooth
- **WHEN** the user drags the separator between the Dashboard plan area and nutrition area vertically
- **THEN** the plan/nutrition height split updates without oscillating or flickering due to the separator view's own movement
- **AND** the separator continues to show the vertical resize cursor while draggable
