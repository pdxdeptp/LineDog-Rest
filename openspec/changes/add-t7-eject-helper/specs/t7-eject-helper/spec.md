## ADDED Requirements

### Requirement: T7 target discovery
The system SHALL discover the target T7 disk without relying on dynamic `/dev/diskN` identifiers.

#### Scenario: Both target volumes are mounted
- **WHEN** `Storage` and `T7 Shield` are visible to the helper
- **THEN** the helper SHALL resolve both volumes
- **AND** confirm they belong to the same APFS container or physical store
- **AND** resolve the physical external whole disk that contains them

#### Scenario: Only Storage is mounted
- **WHEN** `Storage` is visible and `T7 Shield` is not mounted
- **THEN** the helper SHALL use `Storage` to resolve the target APFS container and physical whole disk
- **AND** attempt the same whole-disk safe eject path

#### Scenario: No target volume is mounted but the target disk is absent
- **WHEN** neither `Storage` nor `T7 Shield` can be discovered on an attached external target
- **THEN** the helper SHALL return `idle_not_connected`
- **AND** SHALL NOT treat the run as an error

#### Scenario: Target volumes resolve to multiple disks
- **WHEN** discovered target volumes do not resolve to the same physical whole disk
- **THEN** the helper MUST refuse to unmount or eject anything
- **AND** return `unsafe_target_multiple_disks`

### Requirement: External-disk safety guard
The system SHALL refuse to operate on internal disks or ambiguous non-external targets.

#### Scenario: Resolved target is internal
- **WHEN** target discovery resolves to a disk whose metadata says it is internal or OS-internal media
- **THEN** the helper MUST refuse to unmount or eject it
- **AND** return `unsafe_target_internal_disk`

#### Scenario: Target identity is ambiguous
- **WHEN** volume names match but stable identifiers, APFS topology, external-device metadata, or optional Samsung T7 metadata conflict
- **THEN** the helper MUST refuse to unmount or eject anything
- **AND** return `unexpected_error` or a more specific unsafe-target reason

#### Scenario: Other external disks are attached
- **WHEN** external disks unrelated to the configured T7 are attached
- **THEN** the helper SHALL NOT unmount or eject those disks
- **AND** SHALL only target the physical disk proven to contain the configured T7 volumes

### Requirement: Time Machine coordination
The helper SHALL coordinate with Time Machine before requesting unmount/eject.

#### Scenario: Time Machine is idle
- **WHEN** `tmutil status` reports `Running = 0`
- **THEN** the helper SHALL proceed to Disk Arbitration without calling `tmutil stopbackup`
- **AND** report `timeMachineWasRunning=false`

#### Scenario: Time Machine is running and stops
- **WHEN** `tmutil status` reports `Running = 1`
- **THEN** the helper SHALL call `tmutil stopbackup`
- **AND** poll until `tmutil status` reports Time Machine is not running
- **AND** wait a configured stability period before unmounting
- **AND** report `timeMachineWasRunning=true` and `timeMachineStopped=true`

#### Scenario: Time Machine remains running
- **WHEN** Time Machine still reports running after the configured timeout
- **THEN** the helper MUST NOT force unmount or eject
- **AND** return `time_machine_still_running`

### Requirement: Disk Arbitration whole-disk eject
The helper SHALL use Disk Arbitration for the core unmount/eject path.

#### Scenario: Disk Arbitration succeeds
- **WHEN** target discovery and Time Machine coordination succeed
- **THEN** the helper SHALL request a whole-disk unmount for the resolved physical target
- **AND** request eject after unmount succeeds
- **AND** return `success`
- **AND** report no remaining mounted target volumes

#### Scenario: Disk Arbitration unmount is refused
- **WHEN** Disk Arbitration returns a dissenter during unmount
- **THEN** the helper MUST NOT call force unmount
- **AND** return `disk_busy` or `disk_arbitration_dissented`
- **AND** include dissenter status, dissenter message when available, and remaining mounted target volumes

#### Scenario: Eject fails after unmount succeeds
- **WHEN** whole-disk unmount succeeds but eject fails
- **THEN** the helper SHALL return `unmount_succeeded_eject_failed`
- **AND** include dissenter details when available
- **AND** report remaining mounted target volumes

#### Scenario: Already unmounted
- **WHEN** the target physical disk is present but target volumes are already unmounted
- **THEN** the helper SHALL return `idle_already_unmounted`
- **AND** SHALL NOT treat the run as an error

### Requirement: No GUI or force path
The system MUST NOT use Finder GUI automation, System Events clicks, AppleScript Finder eject, or default force unmount behavior.

#### Scenario: Helper performs an eject
- **WHEN** the helper runs in either scheduled or manual mode
- **THEN** it SHALL NOT open Finder windows
- **AND** SHALL NOT click system UI
- **AND** SHALL NOT call Finder through AppleScript as the main eject path
- **AND** SHALL NOT use `force` unless a future explicitly confirmed dangerous action is designed

### Requirement: Structured result contract
The helper SHALL emit a structured JSON result for every run.

#### Scenario: Successful result
- **WHEN** the target disk is safely unmounted and ejected
- **THEN** stdout SHALL contain JSON with `status="success"`
- **AND** include `action`, `wholeDisk`, `volumes`, Time Machine fields, `remainingMountedVolumes`, and a Chinese `message`

#### Scenario: Failed result
- **WHEN** the helper cannot safely eject the disk
- **THEN** stdout SHALL contain JSON with `status="failed"`
- **AND** include a `reason` from the supported failure categories
- **AND** include enough diagnostic fields for MalDaze to show a concise status and retain a useful log

#### Scenario: Idle result
- **WHEN** the disk is not connected or already unmounted
- **THEN** stdout SHALL contain JSON with `status="idle"`
- **AND** include `reason="idle_not_connected"` or `reason="idle_already_unmounted"`

### Requirement: Diagnostic logging
The system SHALL write one diagnostic log entry for every scheduled or manual run.

#### Scenario: Run completes
- **WHEN** a helper run returns any success, failed, or idle result
- **THEN** the app or helper SHALL append a log entry containing timestamp, target volume evidence, physical whole disk when known, Time Machine state, final result, and remaining mounted volumes

#### Scenario: Helper crashes or emits invalid JSON
- **WHEN** the helper exits unexpectedly or emits invalid JSON
- **THEN** `T7EjectService` SHALL record `unexpected_error`
- **AND** preserve stderr or process failure information in the diagnostic log

### Requirement: App-bound automatic scheduling
The app SHALL schedule automatic T7 eject attempts while MalDaze is running.

#### Scenario: Default automatic mode
- **WHEN** MalDaze starts and the user has not configured T7 automation before
- **THEN** automatic T7 eject SHALL be enabled by default
- **AND** the app SHALL schedule attempts for the configured nightly window

#### Scenario: User disables automatic mode
- **WHEN** the user turns off automatic T7 eject
- **THEN** the app SHALL cancel pending automatic attempts
- **AND** SHALL keep the manual eject action available

#### Scenario: Nightly retry window
- **WHEN** automatic mode is enabled and local time enters the configured window
- **THEN** the app SHALL try at the configured retry interval
- **AND** use default values of 20:00 start, 23:45 end, and 15 minutes retry interval unless the user has changed them

#### Scenario: Success stops retries for the day
- **WHEN** a scheduled run returns `success` or `idle_already_unmounted`
- **THEN** the app SHALL stop additional scheduled attempts for that local day

#### Scenario: Not connected does not stop retries
- **WHEN** a scheduled run returns `idle_not_connected`
- **THEN** the app SHALL log the idle result
- **AND** keep later attempts in the same nightly window eligible

#### Scenario: MalDaze quits
- **WHEN** MalDaze quits
- **THEN** no LaunchAgent, cron, or detached scheduler SHALL continue T7 eject attempts

### Requirement: Manual safe eject
The app SHALL allow the user to trigger the same safe eject helper path manually.

#### Scenario: Manual run outside schedule window
- **WHEN** the user clicks the manual safe-eject action outside the configured nightly window
- **THEN** `T7EjectService` SHALL invoke the helper immediately
- **AND** display the structured result when it completes

#### Scenario: Manual run while scheduled run is active
- **WHEN** a helper run is already in progress
- **THEN** the app SHALL prevent a concurrent manual run
- **AND** keep the UI in an in-progress state until the active run finishes
