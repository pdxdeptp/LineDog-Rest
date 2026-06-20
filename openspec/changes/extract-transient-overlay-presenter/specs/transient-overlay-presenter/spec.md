## ADDED Requirements

### Requirement: Transient overlay presenter SSOT

MalDaze SHALL provide a single `MalDazeTransientOverlayPresenter` (or equivalent type satisfying `MalDazeTransientOverlayPresenting`) as the sole owner of transient overlay AppKit window lifecycle for center bell, hydration reminder, and smart reminder input/toast surfaces.

#### Scenario: Schedulers delegate presentation

- **WHEN** a hydration timer fires, a center bell is requested, or smart reminder UI is opened
- **THEN** the scheduling/orchestration layer delegates window creation, positioning, ordering, dismissal, and screen-change repositioning to the transient overlay presenter
- **AND** scheduling controllers do not retain their own `NSPanel` instances for those surfaces

### Requirement: Passive overlay presentation policy

Passive transient overlays (center bell and hydration reminder) SHALL use a non-activating borderless `NSPanel` at `.screenSaver` level with `[.canJoinAllSpaces, .stationary]` collection behavior, and SHALL call `orderFrontRegardless()` to appear above other applications.

#### Scenario: Center bell passive surface

- **WHEN** the system presents a center bell overlay
- **THEN** the presenter creates a non-activating panel at `.screenSaver` level
- **AND** the overlay is dismissible by the existing click/tap interaction
- **AND** the presenter does not call `NSApp.activate(ignoringOtherApps: true)` for this surface

#### Scenario: Hydration passive surface

- **WHEN** the system presents a hydration reminder overlay
- **THEN** the presenter creates a non-activating panel at `.screenSaver` level
- **AND** the overlay shows the existing hydration icon, message, and action buttons
- **AND** the presenter does not call `NSApp.activate(ignoringOtherApps: true)` for this surface

### Requirement: Dashboard z-order invariance for passive overlays

When presenting a passive transient overlay, the system SHALL preserve the desk-pet Dashboard window's ordering relative to other applications if the Dashboard is already visible.

#### Scenario: Dashboard visible behind another app

- **WHEN** a passive overlay is presented
- **AND** the desk-pet Dashboard window is visible
- **AND** MalDaze was not active immediately before presentation
- **THEN** the overlay appears above other applications
- **AND** the Dashboard remains below other applications

#### Scenario: Dashboard actively in use

- **WHEN** a passive overlay is presented
- **AND** MalDaze was active immediately before presentation
- **THEN** the overlay appears above the desktop
- **AND** the presenter does not demote the Dashboard below other applications

#### Scenario: Explicit Dashboard focus unchanged

- **WHEN** the user opens or focuses the Dashboard through Dock, desk pet, or dashboard shortcut entry points
- **THEN** the system may activate MalDaze and bring the Dashboard forward
- **AND** passive overlay presentation policy does not alter those explicit entry points

### Requirement: Interactive smart reminder overlay policy

Smart reminder input and toast overlays SHALL use the interactive anchored presentation policy: they MAY activate MalDaze and become key windows so the user can type, submit, or undo, and they SHALL clamp positioning to the anchor screen `visibleFrame`.

#### Scenario: Smart reminder input opens as interactive overlay

- **WHEN** the user opens smart reminder input from the desk pet or global shortcut
- **THEN** the presenter shows the existing multi-line input capture surface
- **AND** the input surface becomes key and focused
- **AND** the panel frame is clamped to the anchor screen visible frame

#### Scenario: Smart reminder toast opens as interactive overlay

- **WHEN** smart reminder orchestration shows a result toast with optional undo
- **THEN** the presenter shows the existing toast surface near the smart reminder anchor
- **AND** the toast uses the existing auto-dismiss and undo semantics

#### Scenario: Smart reminder draft and dismissal preserved

- **WHEN** the user dismisses smart reminder input by Esc, cancel, or outside click
- **THEN** the presenter tears down only the input overlay
- **AND** the existing draft retention behavior remains unchanged

### Requirement: Unified screen-change repositioning

The transient overlay presenter SHALL observe `NSApplication.didChangeScreenParametersNotification` for visible overlays it owns and reposition them using the same screen-selection rules as their initial presentation.

#### Scenario: Passive overlay recenters on screen change

- **WHEN** a passive centered overlay is visible and display parameters change
- **THEN** the presenter recenters the overlay on the menu-bar screen visible frame

#### Scenario: Interactive overlay reclamps on screen change

- **WHEN** an interactive anchored overlay is visible and display parameters change
- **THEN** the presenter reclamps the overlay frame against the anchor screen visible frame

### Requirement: Content builders remain separate from shell

The presenter SHALL own overlay shell behavior while content builders supply icons, copy, buttons, or SwiftUI hosting for each overlay kind without duplicating panel lifecycle code.

#### Scenario: Hydration content reuse

- **WHEN** the hydration reminder is presented through the presenter
- **THEN** the overlay retains the existing hydration card visual design and button actions
- **AND** only the shell/lifecycle code is shared

#### Scenario: Center bell content reuse

- **WHEN** the center bell is presented through the presenter
- **THEN** the overlay retains the existing bell icon, message layout, and click-to-dismiss behavior
- **AND** only the shell/lifecycle code is shared
