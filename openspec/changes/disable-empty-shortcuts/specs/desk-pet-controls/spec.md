## ADDED Requirements

### Requirement: Shortcut disabled state
The system SHALL allow every global shortcut row in MalDaze settings to be disabled by leaving shortcut input empty.

#### Scenario: Empty input disables shortcut
- **WHEN** the user starts recording any shortcut row and exits recording without entering a shortcut
- **THEN** the system persists that shortcut as disabled
- **AND** the row displays `已关闭`

#### Scenario: Explicit close action disables shortcut
- **WHEN** the user activates the close/disable action for any shortcut row
- **THEN** the system persists that shortcut as disabled
- **AND** the row displays `已关闭`

#### Scenario: Disabled shortcut is not registered
- **WHEN** the system syncs Carbon global hot key registration for a disabled shortcut
- **THEN** the system unregisters any existing hot key for that action
- **AND** the system does not call Carbon registration for that disabled shortcut

#### Scenario: Restore default remains available
- **WHEN** the user activates the restore-default action for a disabled shortcut row
- **THEN** the system restores that row's built-in default key code, modifiers, and label
- **AND** the shortcut can be registered again on the next hot key sync
