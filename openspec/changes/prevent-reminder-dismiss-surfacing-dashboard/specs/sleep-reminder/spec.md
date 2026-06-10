## ADDED Requirements

### Requirement: Center bell dismissal preserves Dashboard z-order
The system SHALL dismiss center bell reminder overlays without foregrounding an already-visible desk-pet Dashboard window.

#### Scenario: User dismisses center bell while Dashboard is visible behind another app
- **WHEN** a center bell reminder is visible
- **AND** the desk-pet Dashboard window is already visible but not frontmost
- **AND** the user clicks the center bell overlay to dismiss it
- **THEN** the center bell overlay disappears
- **AND** the Dashboard window remains in its prior z-order relative to other applications

#### Scenario: Explicit Dashboard entry points still focus Dashboard
- **WHEN** the user opens the Dashboard through the Dock icon, desk pet click, or desk-pet menu shortcut
- **THEN** the system may activate MalDaze and bring the Dashboard to the front
