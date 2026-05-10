## ADDED Requirements

### Requirement: Persisted desk pet animation preference

The system SHALL persist a boolean preference indicating whether the desk pet icon SHALL animate (GIF frame playback and variant rotation) when displayed in the idle desk pet window.

#### Scenario: Default matches existing behavior

- **WHEN** the user has never set the preference
- **THEN** the system SHALL treat animation as **enabled** (equivalent to current behavior before this change)

#### Scenario: Preference survives relaunch

- **WHEN** the user disables animation and quits the application
- **THEN** on the next launch the system SHALL still apply the disabled-animation behavior until the user changes it again

### Requirement: Shared control panel exposes animation toggle with menu bar / desk pet parity

The system SHALL provide a single animation toggle inside the **shared** control panel content (`MenuBarContentView`), placed **together with the other primary toggles / controls** (same scroll/column structure as existing settings such as Pomodoro durations and shortcuts), **not** as a separate top chrome strip that only wraps one presentation.

The system SHALL present **the same** `MenuBarContentView` instance layout from **both** entry points: the **menu bar status-item popover** and the **desk pet `NSPopover`**, such that the animation toggle is **visible and functional in both** presentations.

#### Scenario: Menu bar entry shows the toggle

- **WHEN** the user opens the control panel from the menu bar status item
- **THEN** the animation toggle SHALL appear in the shared panel alongside the other controls (not hidden or omitted compared to the desk pet entry)

#### Scenario: Desk pet entry shows the same toggle

- **WHEN** the user opens the control panel from the idle desk pet window
- **THEN** the animation toggle SHALL appear in the **same relative location** within `MenuBarContentView` as when opened from the menu bar (same layout; no desk-pet-only extra toolbar above the shared content)

#### Scenario: Toggle updates preference from either entry

- **WHEN** the user toggles the control from either the menu bar panel or the desk pet panel
- **THEN** the system SHALL persist the new boolean preference and SHALL apply it to the desk pet renderer without requiring the user to use a specific entry point

### Requirement: Static mode freezes GIF and variant rotation

When animation is disabled, the system SHALL stop GIF frame animation for the desk pet `PetRenderer` and SHALL NOT schedule or continue periodic rotation among multiple GIF assets for continuous display modes.

#### Scenario: No periodic variant swaps while static

- **WHEN** animation is disabled while the desk pet is showing a multi-variant continuous mode
- **THEN** the system SHALL not switch to a different GIF asset solely due to the periodic variant rotation timer until animation is enabled again or display mode is reset in a way that explicitly reloads assets

#### Scenario: Animation re-enabled restores motion

- **WHEN** the user enables animation again
- **THEN** the system SHALL resume GIF frame animation and SHALL restore periodic variant rotation behavior consistent with the active `PetDisplayMode` rules
