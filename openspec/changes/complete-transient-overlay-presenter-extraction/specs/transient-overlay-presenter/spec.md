## MODIFIED Requirements

### Requirement: Transient overlay presenter SSOT

MalDaze SHALL provide a single `MalDazeTransientOverlayPresenter` (or equivalent type satisfying `MalDazeTransientOverlayPresenting`) as the sole owner of transient overlay AppKit window lifecycle for center bell, hydration reminder, and smart reminder input/toast surfaces. Sole ownership includes panel creation, retention, positioning, ordering, dismissal, closing, and screen-change repositioning; orchestration layers MAY retain business state, event monitors, and timers but MUST NOT retain the owned panel instances.

#### Scenario: Schedulers delegate presentation

- **WHEN** a hydration timer fires, a center bell is requested, or smart reminder UI is opened
- **THEN** the scheduling/orchestration layer delegates window creation, positioning, ordering, dismissal, closing, and screen-change repositioning to the transient overlay presenter
- **AND** scheduling/orchestration components do not retain their own `NSPanel` instances for those surfaces

#### Scenario: Smart reminder orchestration remains outside the shell owner

- **WHEN** `WindowManager` coordinates smart reminder draft, submit, cancel monitors, or toast auto-dismiss timing
- **THEN** it uses narrow presenter queries and dismiss commands
- **AND** it does not create, retain, close, or directly order the smart reminder panel

### Requirement: Interactive smart reminder overlay policy

Smart reminder input and toast overlays SHALL use the interactive anchored presentation policy: the presenter SHALL own their panel shells, the input MAY activate MalDaze and become key so the user can type and submit, and both surfaces SHALL clamp positioning to the anchor screen `visibleFrame`.

#### Scenario: Smart reminder input opens as interactive overlay

- **WHEN** the user opens smart reminder input from the desk pet or global shortcut
- **THEN** the presenter creates and retains the panel shell containing the existing multi-line input surface
- **AND** the input surface becomes key and focused
- **AND** the panel frame is clamped to the anchor screen visible frame

#### Scenario: Smart reminder toast opens as interactive overlay

- **WHEN** smart reminder orchestration shows a result toast with optional undo
- **THEN** the presenter creates and retains the toast panel shell near the smart reminder anchor
- **AND** the toast uses the existing auto-dismiss and undo semantics

#### Scenario: Smart reminder draft and dismissal preserved

- **WHEN** the user dismisses smart reminder input by Esc, cancel, or outside click
- **THEN** the presenter tears down only the input overlay through an idempotent dismiss command
- **AND** the existing draft retention behavior remains unchanged

#### Scenario: Dismissed input is not revived by delayed focus

- **WHEN** an input overlay is dismissed or replaced before its scheduled focus work executes
- **THEN** the stale focus work does not activate MalDaze
- **AND** it does not order, focus, or redisplay the dismissed or replaced panel

### Requirement: Unified screen-change repositioning

The transient overlay presenter SHALL observe `NSApplication.didChangeScreenParametersNotification` whenever any owned overlay is visible and SHALL reposition every visible overlay using the same screen-selection rules and stored presentation inputs as its initial presentation.

#### Scenario: Passive overlay recenters on screen change

- **WHEN** a passive centered overlay is visible and display parameters change
- **THEN** the presenter recenters the overlay on the menu-bar screen visible frame

#### Scenario: Interactive overlay reclamps on screen change

- **WHEN** an interactive anchored overlay is visible and display parameters change
- **THEN** the presenter reclamps the overlay frame against the anchor screen visible frame

#### Scenario: Observer remains while another overlay is visible

- **WHEN** one overlay is dismissed while at least one other owned overlay remains visible
- **THEN** the presenter keeps the screen-change observer installed
- **AND** the remaining overlay continues to reposition on display changes

### Requirement: Content builders remain separate from shell

The presenter SHALL own overlay shell behavior while content builders supply icons, copy, buttons, or SwiftUI hosting for each overlay kind without creating or retaining an AppKit panel.

#### Scenario: Hydration content reuse

- **WHEN** the hydration reminder is presented through the presenter
- **THEN** the overlay retains the existing hydration card visual design and button actions
- **AND** only the shell/lifecycle code is shared

#### Scenario: Center bell content reuse

- **WHEN** the center bell is presented through the presenter
- **THEN** the overlay retains the existing bell icon, message layout, and click-to-dismiss behavior
- **AND** only the shell/lifecycle code is shared

#### Scenario: Smart reminder content builder does not own panels

- **WHEN** smart reminder input or toast content is built
- **THEN** the builder returns hosted content and sizing information without constructing an `NSPanel`
- **AND** the presenter constructs and owns the corresponding interactive panel shell
