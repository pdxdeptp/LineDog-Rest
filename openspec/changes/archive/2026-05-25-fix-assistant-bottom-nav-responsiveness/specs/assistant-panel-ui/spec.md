## ADDED Requirements

### Requirement: Bottom navigation responsiveness
The learning assistant bottom navigation SHALL switch selected tabs immediately and expose a reliable hit target for each visible item.

#### Scenario: Immediate tab selection feedback
- **WHEN** the backend is ready and the user clicks any bottom-navigation item
- **THEN** the selected tab state changes before any destination-specific data refresh is required to complete
- **AND** the clicked item renders selected visual feedback in the same UI update cycle

#### Scenario: Full item hit target
- **WHEN** the user clicks within the visible bounds of a bottom-navigation item, including padding around its icon or label
- **THEN** the system treats the click as activation of that item
- **AND** neighboring navigation items are not activated

#### Scenario: Destination load does not block navigation
- **WHEN** the destination tab starts an async refresh on entry
- **THEN** the assistant still displays the destination tab immediately
- **AND** loading feedback, if needed, is shown inside the destination content rather than delaying tab selection
