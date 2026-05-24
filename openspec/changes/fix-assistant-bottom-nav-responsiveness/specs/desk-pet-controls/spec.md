## ADDED Requirements

### Requirement: Dashboard Panel internal click stability
Dashboard Panel dismissal logic SHALL preserve the panel when the user clicks inside the Dashboard Panel content.

#### Scenario: Bottom navigation click stays in panel
- **WHEN** the Dashboard Panel is visible
- **AND** the user clicks a learning assistant bottom-navigation item inside the panel
- **THEN** the panel remains visible
- **AND** the learning assistant selected tab changes according to the clicked item

#### Scenario: Internal click during focus transition
- **WHEN** the Dashboard Panel is visible and the app processes a focus or activation transition
- **AND** the original mouse event location is inside the Dashboard Panel frame
- **THEN** click-away or app-deactivation dismissal does not hide the panel for that internal click

#### Scenario: Outside click still dismisses
- **WHEN** the Dashboard Panel is visible
- **AND** the user clicks outside both the Dashboard Panel and the desk-pet window
- **THEN** the panel closes or hides using the existing Dashboard Panel dismissal behavior
