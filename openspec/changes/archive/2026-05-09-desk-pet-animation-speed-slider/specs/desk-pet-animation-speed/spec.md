## ADDED Requirements

### Requirement: Persisted animation intensity for desk pet

The system SHALL persist a scalar **animation intensity** in the closed interval **[0, 1]** for the idle desk pet window, where **0** means fully static behavior and **1** means the same full-motion behavior as the pre-slider product baseline (full GIF playback and existing variant-rotation rules at maximum speed).

#### Scenario: Legacy boolean preference migrates

- **WHEN** the user upgrades from a release that stored only a boolean animation preference and no intensity value exists yet
- **THEN** the system SHALL initialize intensity to **0** if the legacy preference was “off” and to **1** if it was “on”, without silently resetting unrelated settings

#### Scenario: Intensity survives relaunch

- **WHEN** the user sets intensity to a value strictly between 0 and 1 and quits the application
- **THEN** on the next launch the system SHALL restore that intensity (within storage precision) until the user changes it again

### Requirement: Shared control panel uses a slider with menu bar / desk pet parity

The system SHALL replace the binary desk pet animation control with a **single slider** shown inside `MenuBarContentView`, embedded **with other primary controls** in the same column/grouping patterns as today (not in a desk-pet-only outer chrome).

The same `MenuBarContentView` layout SHALL be used when opening the panel from the **menu bar status item** and from the **desk pet popover**, so the slider is **visible and functional in both** presentations at the **same relative location**.

#### Scenario: Endpoints behave as static vs full baseline

- **WHEN** the user sets the slider to its **minimum** endpoint
- **THEN** the desk pet SHALL exhibit **fully static** rendering equivalent to the archived “animation off” behavior (including no periodic variant rotation solely from the rotation timer)

- **WHEN** the user sets the slider to its **maximum** endpoint
- **THEN** the desk pet SHALL exhibit **full motion** consistent with the archived “animation on” baseline for the active `PetDisplayMode`

#### Scenario: Mid-range varies perceived speed monotonically

- **WHEN** the user sets the slider to a value strictly between the minimum and maximum
- **THEN** the system SHALL render motion with **greater perceived animation activity** at higher intensity values than at lower intensity values under the same `PetDisplayMode` (monotonic in user-visible dynamism along the slider direction)

#### Scenario: Slider does not spam the app on drag

- **WHEN** the user drags the slider continuously
- **THEN** persistence and renderer refresh triggers SHALL NOT apply unbounded per-tick side effects on the main thread (the implementation MAY commit on drag end or throttle updates)

### Requirement: Notification or equivalent refresh path for intensity

The system SHALL propagate intensity changes to the running desk pet renderer via a documented mechanism (such as a `Notification` or direct view-model hook) so that updates take effect without requiring an application restart.

#### Scenario: Change applies live after commit

- **WHEN** the user finishes adjusting intensity (e.g. releases the slider) from either entry point
- **THEN** the desk pet SHALL update to reflect the new intensity without requiring relaunch
