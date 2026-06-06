## Why

The user keeps a Samsung T7 Shield SSD attached to the Mac, with `Storage` and `T7 Shield` mounted from the same APFS external device and `T7 Shield` serving as the Time Machine backup volume. A shell-based `diskutil unmountDisk /dev/diskN` schedule is unreliable because disk identifiers change and Time Machine, Spotlight, Finder, or filesystem flushes can temporarily block unmounts.

MalDaze should provide a safe, diagnosable, non-GUI eject path that matches Finder's "eject all volumes on this disk" result without automating Finder or using force.

## What Changes

- Add a bundled Swift `T7EjectHelper` command-line helper that discovers the target T7 by volume identity, validates it is external, stops/waits for Time Machine when needed, unmounts all volumes on the physical disk through Disk Arbitration, ejects the disk, and returns structured JSON.
- Add a MalDaze-side `T7EjectService` that owns daily scheduling, manual triggering, helper invocation, result parsing, logging, and status state.
- Enable automatic T7 eject by default, while allowing the user to turn it off from the desk-pet panel.
- Add a right-column desk-pet control for manual "safe eject T7" so the user can bypass Finder's extra "eject all volumes" confirmation while still using the same safe whole-disk behavior.
- Bind the automation lifecycle to MalDaze only: no LaunchAgent in this change, no cron, and no background work after MalDaze quits.
- Do not use Finder GUI automation, AppleScript Finder eject, System Events clicks, dynamic `/dev/diskN` configuration, or default force unmount behavior.

## Capabilities

### New Capabilities
- `t7-eject-helper`: Safe T7 target discovery, Time Machine coordination, Disk Arbitration whole-disk unmount/eject, structured results, app-bound scheduling, and diagnostic logging.

### Modified Capabilities
- `desk-pet-controls`: The desk-pet panel right column gains T7 auto-eject controls, manual safe-eject action, and latest result/status display.

## Affected Specs

- `t7-eject-helper`
- `desk-pet-controls`

## Impact

- Swift app code:
  - `MalDaze/AppViewModel.swift`
  - `MalDaze/MalDazeDefaults.swift`
  - `MalDaze/DashboardRootView.swift`
  - `MalDaze/Settings/MalDazeSettingsView.swift` if shared defaults need a settings mirror
  - new `MalDaze/T7Eject/` service, scheduler, models, and process wrapper files
- Xcode project:
  - add a command-line helper target or equivalent bundled executable for `T7EjectHelper`
  - link Disk Arbitration and IOKit where needed
  - copy the helper into the app bundle for runtime invocation
- Tests:
  - pure Swift tests for target resolution, Time Machine status parsing, scheduler policy, JSON result parsing, manual action state, unsafe target rejection, idle states, and source-level assertions that Finder/AppleScript/force paths are not used
- Runtime systems:
  - Disk Arbitration
  - IOKit/disk description metadata
  - `tmutil status` and `tmutil stopbackup`
  - local JSONL logs under MalDaze application support or logs directory
