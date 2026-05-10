## ADDED Requirements

### Requirement: Shared popover exposes desk pet icon side length above animation intensity

The system SHALL provide a **single control** for idle desk pet **icon side length** (in points) inside `MenuBarContentView`, using a **slider-style** control (continuous drag with **step 4** between stored values), bound to `MalDazeDefaults.idlePetIconSidePoints` within `MalDazeDefaults.idlePetIconSideMin` and `MalDazeDefaults.idlePetIconSideMax`.

The icon side length control SHALL appear **visually above** the existing **desk pet animation intensity** slider in the same panel layout, preserving the same relative order in both the menu bar popover and the desk pet popover presentations.

#### Scenario: Menu bar and desk pet show the same ordering

- **WHEN** the user opens the control panel from the **menu bar** or from the **desk pet** entry point
- **THEN** the icon side length control SHALL appear **above** the animation intensity slider (not below it)

#### Scenario: Drag does not spam persistence or sync

- **WHEN** the user **drags** the icon side length slider continuously
- **THEN** the system SHALL NOT apply unbounded per-tick side effects equivalent to repeated full persistence-and-notification bursts on the main thread (the implementation MAY commit storage and broadcast refresh **on drag end** or throttle updates similarly to the animation intensity slider)

#### Scenario: Change applies to hit area and rendering

- **WHEN** the user finishes adjusting icon side length and the stored value updates
- **THEN** the running idle pet window SHALL resize its content and **click hit region** consistently with the existing `idlePetIconSidePoints` semantics (no regression versus the prior Settings stepper behavior)

### Requirement: Settings no longer duplicates icon side length

The system SHALL **remove** the previous **Stepper** (or equivalent) row labeled for idle desk pet icon side length from `MalDazeSettingsView` under the section that groups **desk pet return-to-corner** shortcuts, so that **popover / panel** is the sole interactive entry point for this preference.

#### Scenario: Settings section retains other controls

- **WHEN** the user opens Settings after this change
- **THEN** the **shortcut recording** and other rows in that section SHALL remain available; only the icon side length stepper SHALL be absent
