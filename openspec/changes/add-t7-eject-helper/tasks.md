## 1. Helper Target And Core Models

- [x] 1.1 Add failing tests or source checks requiring a bundled `T7EjectHelper` executable target, app-bundle copy integration, and Disk Arbitration/IOKit linkage.
- [x] 1.2 Add the `T7EjectHelper` command-line target and bundle-copy project wiring with a thin executable entry point.
- [x] 1.3 Add failing Swift tests for `T7EjectResult` JSON decoding/encoding across `success`, `failed`, and `idle` outcomes with the required diagnostic fields.
- [x] 1.4 Implement shared result/status models, reason enums, Chinese message mapping, and stdout JSON formatting.

## 2. Target Discovery And Safety

- [ ] 2.1 Add failing resolver fixture tests for both target volumes mounted, only `Storage` mounted, target absent, target already unmounted, multiple physical disks, internal disk rejection, and unrelated external disks.
- [ ] 2.2 Implement protocol-based disk inventory models that represent volumes, APFS containers, physical stores, external/internal metadata, stable identifiers, and physical whole-disk resolution.
- [ ] 2.3 Implement conservative T7 target resolution using volume names, persisted/seed stable identifiers, APFS topology, external-disk metadata, and optional Samsung T7 media metadata.
- [ ] 2.4 Add failing source-level tests proving the helper does not hard-code dynamic `/dev/diskN` identifiers for configuration.
- [ ] 2.5 Perform spec compliance and code quality review for target discovery against unsafe-target, idle, and single-disk consistency scenarios.

## 3. Time Machine And Disk Arbitration

- [ ] 3.1 Add failing tests for `tmutil status` parsing with `Running = 0`, `Running = 1`, malformed output, and command failure.
- [ ] 3.2 Implement the Time Machine controller abstraction with `tmutil status`, `tmutil stopbackup`, polling timeout, and post-stop stability wait.
- [ ] 3.3 Add failing tests for Time Machine still-running timeout and successful stop-before-unmount sequencing.
- [ ] 3.4 Add failing tests for Disk Arbitration wrapper outcomes: unmount success then eject success, unmount dissenter, eject dissenter after unmount, and remaining mounted-volume evidence.
- [ ] 3.5 Implement the Disk Arbitration session wrapper, whole-disk unmount/eject callbacks, dissenter mapping, and no-force operation path.
- [ ] 3.6 Add failing source-level tests rejecting Finder automation, System Events, Finder AppleScript eject, and default force unmount/eject usage.
- [ ] 3.7 Perform spec compliance and code quality review for Time Machine coordination, Disk Arbitration result mapping, and no-GUI/no-force guarantees.

## 4. App Service, Scheduling, And Logging

- [ ] 4.1 Add failing tests for `T7EjectService` helper invocation, stdout JSON parsing, invalid JSON handling, process failure handling, in-flight concurrency prevention, and diagnostic log writes.
- [ ] 4.2 Implement `T7EjectService` with injectable process runner, clock/calendar, helper path resolution, JSON result parsing, observable state, and JSONL logging.
- [ ] 4.3 Add failing scheduler tests for default auto-enabled behavior, 20:00-23:45 local window, 15-minute retry interval, daily success suppression, `idle_already_unmounted` daily completion, `idle_not_connected` continued retry eligibility, manual runs outside the window, and disabled-auto cancellation.
- [ ] 4.4 Implement the app-bound scheduler, persisted defaults, daily completion tracking, and app lifecycle start/stop integration through `AppViewModel`.
- [ ] 4.5 Add failing tests proving no LaunchAgent, cron, or detached scheduler is installed for T7 eject.
- [ ] 4.6 Perform spec compliance and code quality review for app-bound lifecycle, scheduling, logging, and helper process safety.

## 5. Desk-Pet Right Column UI

- [ ] 5.1 Add failing source/UI tests requiring a `T7 安全推出` section in the desk-pet panel right column.
- [ ] 5.2 Add failing tests for default-on automatic toggle, persisted off state, manual button availability while auto is off, in-progress disabled state, schedule configuration persistence, and latest-result display.
- [ ] 5.3 Implement right-column T7 controls in the dashboard/control surface and bind them to `T7EjectService`.
- [ ] 5.4 Add concise Chinese status copy for success, idle, busy/dissenter, Time Machine still running, unsafe target, eject failed after unmount, and unexpected error.
- [ ] 5.5 Perform spec compliance and code quality review for desk-pet-controls UI requirements and status presentation.

## 6. Verification And Manual QA

- [ ] 6.1 Run `openspec validate add-t7-eject-helper --strict` or the repository's equivalent OpenSpec validation.
- [ ] 6.2 Run the relevant Swift/Xcode test suite for MalDaze and `T7EjectHelper`.
- [ ] 6.3 Manually verify with the T7 disconnected that scheduled/manual helper paths return idle without an error UI.
- [ ] 6.4 Manually verify with only `Storage` mounted that the helper resolves the same physical T7 target and attempts the safe whole-disk eject path.
- [ ] 6.5 Manually verify with both `Storage` and `T7 Shield` mounted and Time Machine idle that `/Volumes/Storage` and `/Volumes/T7 Shield` disappear after success.
- [ ] 6.6 Manually verify with Time Machine running that the helper stops backup, waits for idle/stability, and either ejects safely or returns `time_machine_still_running`.
- [ ] 6.7 Manually verify that failed/busy cases do not use force and show a diagnostic right-column message.
- [ ] 6.8 Confirm the feature runs only while MalDaze is running and does not install or depend on LaunchAgent/cron behavior.
