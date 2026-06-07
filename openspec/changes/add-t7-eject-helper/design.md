## Context

MalDaze is a native Swift macOS desk-pet app. Existing local background behavior such as hydration reminders and timers is owned by `AppViewModel` and controller objects inside the app process. The learning assistant backend is a separate Python process, but this T7 eject feature is macOS device-management behavior and should stay in Swift rather than the Python backend.

The user's Samsung T7 Shield currently appears as an external physical disk with a GUID partition map, an APFS physical store, an APFS container, and two target volumes:

```text
disk4 physical external USB, media "PSSD T7 Shield"
  disk4s2 APFS Physical Store
    disk5 APFS container
      disk5s1 Storage
      disk5s2 T7 Shield, APFS role Backup
```

This topology matters because APFS volume `ParentWholeDisk` can point at the virtual APFS container (`disk5`) rather than the physical eject target (`disk4`). The helper must resolve the physical external whole disk before ejecting, while still using the target volumes as the identity anchor.

Apple's Disk Arbitration API provides the primary non-GUI path: create a session, resolve disk objects, unmount all volumes through a whole-disk unmount, then eject the whole disk. On Samsung T7 Shield media that reports as fixed USB media, direct `DADiskEject` can return a lower-level `0xc010` refusal while Finder can still eject through macOS's DiskManagement path. For that specific post-unmount refusal, the helper may fall back to non-force `diskutil eject <wholeDisk>`; it still must not use Finder automation or force. Time Machine adds a separate coordination step: when `tmutil status` reports `Running = 1`, the helper should call `tmutil stopbackup`, wait until the backup is not running, then allow a short stability period for backupd, Spotlight, Finder, and filesystem flushes.

## Goals / Non-Goals

**Goals:**

- Safely unmount and eject the physical T7 disk containing `Storage` and `T7 Shield`.
- Match Finder's practical "eject all volumes on this disk" result without Finder automation or GUI interaction.
- Enable automatic nightly eject by default, with a right-column desk-pet toggle to disable it.
- Provide a manual right-column action that performs the same safe helper path immediately.
- Keep scheduling and lifecycle fully inside MalDaze: when MalDaze is closed, no LaunchAgent or cron continues this feature.
- Return and log structured JSON so failures are diagnosable.
- Cover discovery, Time Machine parsing, scheduling, status mapping, unsafe targets, idle cases, and UI integration with deterministic tests.

**Non-Goals:**

- No Finder GUI automation, System Events clicking, or AppleScript Finder eject as the main path.
- No default `force` unmount/eject behavior.
- No LaunchAgent, cron, or background job that survives MalDaze quitting.
- No Time Machine configuration changes.
- No physical power-off requirement after macOS considers the disk safe to remove.
- No broad generic external-disk eject UI; this change targets the configured T7 identity.

## Decisions

### Decision 1: Bundle a Swift command-line helper, invoked by a Swift app service

Create a `T7EjectHelper` executable target and bundle it inside the MalDaze app. The app-side `T7EjectService` invokes the helper as a one-shot child process, reads stdout JSON, captures stderr for diagnostics, and updates observable state for the desk-pet right column.

Rationale: Disk Arbitration and IOKit are native macOS APIs and belong in a small Swift helper that can run outside SwiftUI view lifecycle concerns. A helper target also isolates lower-level blocking work from the main app, while keeping lifecycle bound to the app because there is no LaunchAgent.

Alternative considered: implement all Disk Arbitration calls directly inside the app process. This reduces target/project complexity but couples long-running Time Machine wait loops and low-level callbacks to the UI app. A helper gives cleaner JSON boundaries and easier manual testing.

Alternative considered: use the existing Python backend. This is a poor fit because ejecting disks is local macOS system integration, not learning-assistant domain logic, and would add another process dependency to a safety-sensitive feature.

### Decision 2: Keep target resolution data-driven and conservative

The helper resolves the target by known volume names and persisted stable identifiers, then validates:

- target volumes are named `Storage` and/or `T7 Shield`;
- any discovered target volumes resolve to the same APFS container and physical whole disk;
- the physical whole disk is external, not internal;
- optional media/model metadata matches the Samsung T7 family when available;
- `T7 Shield` may be identified as an APFS Backup role when visible;
- expected Volume UUIDs, APFS container UUID, physical store UUID, or media name may be stored for stronger matching after first successful discovery.

The current observed identifiers should be used as seed data where useful:

- `Storage` Volume UUID: `16200DE4-3800-4E29-830B-6CD1211E02C5`
- `T7 Shield` Volume UUID: `C34DAAF1-3BDB-4B62-80F9-4621158F1A8E`
- APFS container UUID: `9E5E6C79-4DFB-481A-BC3C-A503BA356A50`
- APFS physical store UUID: `AB8EBBC8-85E3-412B-8EE4-F5AD94248842`
- media name: `PSSD T7 Shield`

Rationale: volume names are user-friendly and match the requirement, but names alone are not enough for a safety-sensitive eject. Stable IDs reduce false positives while still avoiding dynamic `/dev/diskN` configuration.

Alternative considered: hard-code current `disk4`/`disk5`. Rejected because disk identifiers are dynamic across reconnects and boots.

Alternative considered: eject any external disk with a `T7 Shield` volume. Rejected because the user also has a `Storage` volume on the same disk and the helper must prove whole-disk consistency.

### Decision 3: Resolve APFS physical whole disk before ejecting

The resolver should treat APFS virtual whole disks and physical whole disks as different layers. Starting from target volume disks, it should use Disk Arbitration descriptions and IOKit media parent traversal to find:

```text
target volume disk(s)
  -> APFS container / physical store
  -> physical external whole disk for eject
```

The Disk Arbitration operation should unmount all volumes associated with the target physical disk and then eject that physical whole disk. If the Disk Arbitration eject step returns the observed fixed-media refusal after unmount has succeeded, the helper may issue one non-force `diskutil eject` fallback against the same physical whole disk. The result JSON should include both the physical `wholeDisk` and, when known, the `apfsContainer`.

Rationale: Finder's result is physical-disk safety, not merely detaching an APFS container. The observed T7 topology makes a naive `DADiskCopyWholeDisk` result potentially ambiguous if it returns the APFS virtual whole disk.

Alternative considered: call `diskutil unmountDisk` or parse `diskutil list` text. Rejected for the core eject path because the old shell approach is the behavior being replaced.

### Decision 4: Coordinate with Time Machine before Disk Arbitration

The helper owns a `TimeMachineController` abstraction:

1. run `tmutil status`;
2. parse `Running = 1` / `Running = 0`;
3. if running, call `tmutil stopbackup`;
4. poll `tmutil status` until not running or timeout;
5. after a stopped/running transition, wait a configurable stability period before unmounting.

Default timeout should be 5 to 10 minutes. Default stability wait should be 10 to 30 seconds. If Time Machine remains running after timeout, return `time_machine_still_running` without unmount/eject and without force.

Rationale: Apple's Time Machine help explicitly points to backup activity, open files, and Spotlight as common blockers. Stopping Time Machine first avoids racing backupd and gives the Disk Arbitration request a Finder-like chance to succeed.

Alternative considered: skip Time Machine and let Disk Arbitration fail if busy. Rejected because this recreates the brittle shell failure mode.

### Decision 5: App-bound scheduler, enabled by default

`T7EjectService` should start with automatic eject enabled by default through registered UserDefaults. The desk-pet right column can turn it off. When enabled, the service schedules local-time attempts inside the configured nightly window:

- default start: 20:00;
- default end: 23:45;
- default retry interval: 15 minutes;
- once a run returns `success` or `idle_already_unmounted`, no further scheduled attempts run that local day;
- `idle_not_connected` is logged but does not count as success, so a later reconnect in the same window can still be caught;
- manual runs are allowed outside the window and share the same no-force helper path.

The scheduling, last-success day, and in-flight state live in the app process. App termination stops future attempts and should not install, update, or depend on any LaunchAgent.

Rationale: the user wants this tied to the desk pet and closed with the desk pet. App-bound scheduling also avoids silently managing disks after the user quits MalDaze.

Alternative considered: LaunchAgent for reliability when the app is not running. Rejected for this change by user decision.

### Decision 6: Right-column UI owns all T7 controls and status

Add a compact `T7 安全推出` section to the desk-pet panel's right column. It should include:

- automatic eject toggle, default on;
- schedule summary and configurable schedule values for the nightly window/retry interval;
- manual safe-eject button;
- in-progress disabled state;
- latest result message and last run time.

Manual eject and scheduled eject must call the same service/helper path. The UI should never expose a default force action. If a future dangerous force action is added, it must require explicit user confirmation and a separate design change.

Rationale: the user specifically wants the feature in the existing desk-pet panel right column and wants manual eject to avoid Finder's extra confirmation flow.

Alternative considered: put configuration only in the macOS Settings scene. Rejected because the requested primary control surface is the desk-pet panel.

### Decision 7: Result JSON and logs are the integration contract

The helper writes a single JSON result to stdout. The app parses that result and maps it to concise Chinese UI copy. Each result is also appended as JSONL to a MalDaze log file. Result records include:

- `status`: `success`, `failed`, or `idle`;
- `reason`: one of the specific categories when applicable;
- `action`;
- `wholeDisk`;
- `apfsContainer`;
- `volumes`;
- `timeMachineWasRunning`;
- `timeMachineStopped`;
- `remainingMountedVolumes`;
- `dissenterStatus`;
- `dissenterMessage`;
- `startedAt`;
- `endedAt`;
- `message`.

Rationale: stdout JSON makes the helper easy to test and invoke manually. JSONL logs preserve the same diagnostic details for later review.

Alternative considered: app directly inspects process exit code and stderr only. Rejected because it loses structured error categories and mounted-volume evidence.

### Decision 8: Keep app-side service, scheduler, and UI seams explicit

The app-side implementation must be split by responsibility even if small types live in the same Swift source file:

- `T7EjectProcessRunning`: one-shot child-process execution with stdout, stderr, exit status, timeout, and spawn-failure reporting.
- `T7EjectHelperPathResolving`: bundled/development helper lookup only; no schedule or UI state.
- `T7EjectLogWriting`: append-only JSONL persistence with injectable file URL or writer for tests.
- `T7EjectSchedulePolicy`: pure local-time eligibility, retry interval, daily completion, and next-attempt decisions.
- `T7EjectService`: orchestration boundary that prevents concurrent runs, invokes the helper, parses stdout JSON, records logs, and publishes latest state.
- `AppViewModel`: lifecycle owner and UI-facing command surface; it may start/stop the service and expose state, but should not parse helper stdout or write logs.
- `DashboardRootView`: presentation only; it may render controls and call `AppViewModel` commands, but must not resolve helper paths, spawn processes, write logs, or know Disk Arbitration details.

Before implementing UI, the service implementation must be reviewed against these seams. If a previous broad implementation combined these responsibilities in a way that makes tests brittle or future UI workers guess, refactor to these seams before adding right-column controls.

Rationale: the original app-service task combined process execution, JSON parsing, logging, scheduling, defaults, lifecycle, and UI state. That made implementation slower and pushed interface design into the apply step. Explicit seams make TDD smaller, allow focused review, and keep the safety-sensitive helper boundary diagnosable.

Apply boundary: do not assign one worker to implement service/scheduler and right-column UI together. UI work starts only after the service state contract is reviewed and stable.

## Risks / Trade-offs

- [Risk] Disk Arbitration metadata can vary by device and macOS version. -> Mitigation: keep resolver protocol-based, log raw relevant metadata in debug records, and validate with both name and stable identifiers.
- [Risk] APFS physical-disk traversal is the trickiest part and may expose different keys than `diskutil -plist`. -> Mitigation: use IOKit parent traversal and add fixture tests that model virtual APFS container vs physical whole disk.
- [Risk] Time Machine may stop but Spotlight or backupd can still hold the disk briefly. -> Mitigation: use a configurable stability wait and return busy/dissenter details instead of forcing.
- [Risk] Automatic default-on behavior can surprise users if they do not notice it. -> Mitigation: right-column section clearly shows the enabled state, latest result, and manual off switch.
- [Risk] Adding a helper target changes Xcode project structure. -> Mitigation: keep shared resolver/status models in regular Swift files with deterministic tests, and keep the executable wrapper thin.
- [Risk] App-bound scheduling does not run if MalDaze is closed. -> Mitigation: this is an explicit product decision; UI copy/status should imply the automation runs while MalDaze is running.
- [Risk] Broad app-side tasks can hide design decisions inside implementation. -> Mitigation: keep service/scheduler/UI seams explicit in this design and add a review gate before UI work.

## Migration Plan

1. Register default UserDefaults for T7 auto eject enabled, schedule window, retry interval, Time Machine timeout, and stability wait.
2. Add the helper target and copy it into the MalDaze app bundle.
3. Add app-side service and bind it into `AppViewModel` startup/termination lifecycle.
4. Review the app-side service against the explicit process/path/log/schedule/service/lifecycle seams before UI work.
5. Add right-column desk-pet controls and result display using the reviewed `AppViewModel` state contract.
6. Add tests and manual QA steps.

Rollback is code-level: disabling/removing the service and helper leaves existing user data untouched. No disk, Time Machine, or database migration is required.

## Open Questions

- Should the first successful discovery persist the observed T7 identifiers automatically, or should the initial identifier list be hard-coded from the observed device and only updated through a future "learn this disk" action?
- Should scheduled `idle_already_unmounted` count as the day's completion when the physical disk is still attached but target volumes are already unmounted? This design says yes; implementation should verify that behavior feels right during manual QA.
