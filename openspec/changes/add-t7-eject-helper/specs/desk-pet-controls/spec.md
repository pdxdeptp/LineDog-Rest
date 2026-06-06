## ADDED Requirements

### Requirement: T7 safe-eject controls in right column
The desk-pet panel SHALL expose T7 safe-eject controls in the panel's right column.

#### Scenario: Right column shows T7 section
- **WHEN** the user opens the desk-pet panel
- **THEN** the right column SHALL include a `T7 安全推出` section
- **AND** the section SHALL show automatic eject state, schedule configuration, manual eject action, and latest result status

#### Scenario: Automatic eject defaults on
- **WHEN** the user has not previously changed the T7 auto-eject setting
- **THEN** the right-column T7 automatic eject toggle SHALL be on
- **AND** MalDaze SHALL schedule automatic attempts while the app is running

#### Scenario: User disables automatic eject
- **WHEN** the user turns off the right-column T7 automatic eject toggle
- **THEN** MalDaze SHALL persist the off state
- **AND** cancel pending automatic T7 attempts
- **AND** leave the manual safe-eject button available

#### Scenario: User configures schedule
- **WHEN** the user edits the T7 nightly window or retry interval in the right-column section
- **THEN** MalDaze SHALL persist the schedule values
- **AND** reschedule future automatic attempts using those values

#### Scenario: Manual safe eject from right column
- **WHEN** the user clicks the right-column manual T7 safe-eject action
- **THEN** MalDaze SHALL invoke the same no-force helper path used by scheduled eject
- **AND** SHALL NOT use Finder, Finder AppleScript, System Events, or GUI clicks

#### Scenario: Manual eject in progress
- **WHEN** a T7 helper run is active
- **THEN** the manual action SHALL be disabled or show an in-progress state
- **AND** the section SHALL continue showing the latest known status without starting a second run

#### Scenario: Status displays helper result
- **WHEN** a scheduled or manual helper run completes
- **THEN** the right-column section SHALL display concise Chinese status based on the helper JSON result
- **AND** include the latest run time when available

#### Scenario: Failed eject remains non-destructive
- **WHEN** the helper returns `disk_busy`, `disk_arbitration_dissented`, `time_machine_still_running`, or another failed result
- **THEN** the right-column section SHALL explain that the disk was not force-ejected
- **AND** SHALL NOT offer an unconfirmed force action
