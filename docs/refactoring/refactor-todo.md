# MalDaze Refactor Todo

Last updated: 2026-06-13

This todo is the execution queue for `openspec/changes/stabilize-core-boundaries`. It should be updated after every refactor step with status and verification evidence.

Status legend:

- `Todo`: Not started.
- `Ready`: Clear enough to implement next.
- `In Progress`: Currently being changed.
- `Blocked`: Needs a decision, spec update, or prerequisite.
- `Done`: Implemented and verified.

## Current Recommended Next Step

Continue with **R8: Introduce typed settings domains for views** when settings/defaults work is explicitly in scope. **R7: Move learning capacity Hermes sync out of defaults** is complete; `LearningSettingsSyncService.swift` now owns learning capacity default/clamp/resolution and Hermes profile sync while `MalDazeDefaults` preserves the old key/API names as compatibility wrappers.

Do not start by splitting `AppViewModel` or `WindowManager`; both are high-impact and should wait until tests and lower-level helpers are stronger.

## Wave 0: Governance Documents

| ID | Status | Risk | Task | Targets | Verification |
| --- | --- | --- | --- | --- | --- |
| R0.1 | Done | Low | Create OpenSpec change for core boundary stabilization | `openspec/changes/stabilize-core-boundaries/` | `openspec status --change stabilize-core-boundaries` |
| R0.2 | Done | Low | Create coupling audit | `docs/refactoring/system-coupling-audit.md` | Source evidence cited for each hotspot |
| R0.3 | Done | Low | Create prioritized refactor todo | `docs/refactoring/refactor-todo.md` | Todo includes status, risk, targets, verification |

## Wave 1: Low-Risk Duplicate Infrastructure

| ID | Status | Risk | Task | Targets | Verification |
| --- | --- | --- | --- | --- | --- |
| R1 | Done | Low | Extract shared FSEvent file watcher | `LearningProjectsFileWatcher`, `SleepScheduleFileWatcher`, `NutritionDailyLogFileWatcher`, `InterventionRequestFileWatcher`, `FileChangeWatcher` | `xcodebuild test -scheme MalDaze -only-testing:MalDazeTests/FileChangeWatcherTests` passed on 2026-06-13; tests cover filename/flag filtering, single callback per event batch, and source-level delegation from domain wrappers |
| R2 | Done | Low-Medium | Consolidate global shortcut value model | `SmartReminderInputShortcut`, `DeskPetMenuShortcut`, `SevenMinuteReminderShortcut`, `ResetIdlePetPositionShortcut`, `GlobalShortcut` | `xcodebuild test -scheme MalDaze -only-testing:MalDazeTests/GlobalShortcutModelTests` passed on 2026-06-13; tests cover missing-key defaults, save/load round trip through existing defaults keys, modifier masking, disabled display, fallback labels, and source-level delegation from all four wrappers |
| R3 | Done | Medium | Table-drive Carbon hotkey registration | `MalDazeCarbonGlobalHotKeys.swift`, `CarbonGlobalHotKeyRegistrationTests` | `xcodebuild test -scheme MalDaze -only-testing:MalDazeTests/CarbonGlobalHotKeyRegistrationTests` passed on 2026-06-13; tests cover hotkey IDs 1/2/3/4, `LDOG` signature, NotificationCenter command names, disabled no-register/unregister state, unchanged retain behavior, changed replacement, and register failure/success state transitions |
| R4 | Done | Medium | Extract Hermes path and process runtime helpers | `HermesRuntime`, `HermesScheduleCLI`, `NutritionHermesCLI`, sleep/intervention/nutrition contract readers | `xcodebuild test -scheme MalDaze -only-testing:MalDazeTests/HermesRuntimeTests` passed on 2026-06-13 after RED compile failure for missing reader URL helpers; `xcodebuild test -scheme MalDaze -only-testing:MalDazeTests/HermesRuntimeTests -only-testing:MalDazeTests/HermesScheduleModelsTests -only-testing:MalDazeTests/SleepScheduleContractTests -only-testing:MalDazeTests/InterventionRequestContractTests -only-testing:MalDazeTests/NutritionDailyLogContractTests -only-testing:MalDazeTests/NutritionRecommendationContractTests -only-testing:MalDazeTests/NutritionTodayViewModelTests` passed on 2026-06-13; tests cover unchanged Hermes path locations, contract reader defaults delegating to `HermesRuntimePaths`, stdout/stderr/status capture, large stdout pipe draining, bounded timeout for SIGTERM-ignoring processes, cancellation cleanup, process-group descendant cleanup, learning CLI runtime delegation, and nutrition timeout message preservation. No new contract risk discovered; JSON schemas, filenames, decoding behavior, and user-facing error strings were unchanged. |

## Wave 2: Settings and Defaults Boundaries

| ID | Status | Risk | Task | Targets | Verification |
| --- | --- | --- | --- | --- | --- |
| R5 | Done | Medium | Split defaults key namespaces from behavior | `MalDazeDefaults.swift`, `MalDazeDefaultsKeys.swift` | `xcodebuild test -scheme MalDaze -only-testing:MalDazeTests/ControlPanelPresentationTests/testMalDazeDefaultsKeyNamespacePreservesExistingKeyContracts` passed on 2026-06-13 after RED compile failure for missing `MalDazeDefaultsKeys`; complete key contract coverage verifies every `MalDaze.*` key literal has `MalDazeDefaults` alias -> `MalDazeDefaultsKeys` namespace -> unchanged literal coverage, `MalDazeDefaults.swift` no longer directly defines key strings, and `MalDazeDefaultsKeys.swift` is registered in the app target Sources. Regression verification also included `xcodebuild test -scheme MalDaze -only-testing:MalDazeTests/PetRendererTests`. |
| R6 | Done | Medium | Move dashboard layout clamp policy out of defaults | `MalDazeDefaults`, dashboard layout tests | `xcodebuild test -scheme MalDaze -only-testing:MalDazeTests/ControlPanelPresentationTests/testDashboardLayoutPolicyResolvesStoredWidthsAndKeepsMiddleFlexible -only-testing:MalDazeTests/ControlPanelPresentationTests/testDashboardLayoutPolicyClampsMinAndOverflowByShavingRightBeforeLeft -only-testing:MalDazeTests/ControlPanelPresentationTests/testDashboardLayoutPolicyClampsAndResolvesLeftPlanFraction -only-testing:MalDazeTests/ControlPanelPresentationTests/testMalDazeDefaultsDashboardLayoutCompatibilityDelegatesToDashboardLayoutPolicy` passed on 2026-06-13 after RED failures for missing `DashboardLayout` policy API and then for missing independent `DashboardLayout.swift` boundary; tests cover stored width fallback, fixed side widths with middle flex, min/middle behavior under narrow layouts, overflow shaving right before left, left-plan fraction default/min/max/resolution, behavior-equivalent `MalDazeDefaults` compatibility delegation, and source guardrails that keep the core algorithm out of `MalDazeDefaults` and `DashboardRootView.swift` |
| R7 | Done | Medium | Move learning capacity Hermes sync out of defaults | `LearningSettingsSyncService`, `HermesLearningProfileStore`, `MalDazeDefaults`, startup/settings/learning panel call sites | `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -destination 'platform=macOS' -only-testing:MalDazeTests/LearningSettingsSyncServiceTests` passed on 2026-06-13 after RED compile failure for missing `LearningSettingsSyncService` and `LearningCapacityProfileStoring`; tests cover missing-default migration syncing 300 minutes, existing defaults not overwritten, clamped rounded sync, startup ensure stale/missing/equal behavior, fail-soft write errors, and source/project guardrails keeping Hermes profile writes out of `MalDazeDefaults` while registering the new service in app target Sources |
| R8 | Todo | Medium | Introduce typed settings domains for views | `DashboardRootView`, `MalDazeSettingsView`, AppViewModel settings sync | Existing settings behavior preserved; NotificationCenter emissions reduced or centralized |

## Wave 3: AppViewModel Boundary Extraction

| ID | Status | Risk | Task | Targets | Verification |
| --- | --- | --- | --- | --- | --- |
| R9 | Todo | High | Extract timer mode and suspended-session policy | `AppViewModel`, timer engines | Tests cover manual/auto start, stop, resume, rest transition, status text |
| R10 | Todo | High | Extract pet display mode mapping | `AppViewModel`, `WindowManaging` facade | Tests cover thinking/resting/running/paused mapping and duplicate window calls |
| R11 | Todo | High | Extract smart reminder UI orchestration boundary | `AppViewModel`, `SmartReminderOrchestrator`, window toast/bell calls | Tests cover submit, saved result, undo, and delayed bell scheduling |
| R12 | Todo | High | Extract reminder lifecycle coordinator | Hydration, sleep, intervention, seven-minute controllers | Tests prove settings changes still reschedule or enable/disable the right controllers |
| R13 | Todo | Medium-High | Extract T7 dashboard adapter | `AppViewModel`, `T7EjectService` UI bridge, Dashboard controls | T7 service tests and dashboard source/behavior tests pass |

## Wave 4: WindowManager Boundary Extraction

| ID | Status | Risk | Task | Targets | Verification |
| --- | --- | --- | --- | --- | --- |
| R14 | Todo | High | Extract dashboard window controller | `WindowManager`, dashboard window layout/delegate/ESC monitor | Tests cover show, hide, persist frame, ESC/Cmd-W handling; manual dashboard QA documented |
| R15 | Todo | High | Extract pet idle window controller | `WindowManager`, pet install/layout/mouse policy | Tests cover frame clamp and mouse policy; manual multi-screen QA documented |
| R16 | Todo | High | Extract rest and breakRun presentation controller | `WindowManager`, `BreakRunController`, `PetStageView` integration | Tests cover callback order and return-to-idle policy; manual rest/breakRun QA documented |
| R17 | Todo | Medium-High | Extract smart input and toast panel controller | `WindowManager`, smart input/toast panel code | Tests cover draft preservation, submit clearing, cancel behavior, auto-dismiss |

## Wave 5: Source-Inspection Test Migration

| ID | Status | Risk | Task | Targets | Verification |
| --- | --- | --- | --- | --- | --- |
| R18 | Todo | Medium | Inventory source-inspection tests by protected regression | `MalDazeTests/*` | Inventory maps each source token check to behavior or guardrail purpose |
| R19 | Todo | High | Replace dashboard/window source-shape checks with behavior or policy tests | `ControlPanelPresentationTests`, extracted dashboard/window policies | Tests no longer depend on exact monolith method names where behavior coverage exists |
| R20 | Todo | Medium-High | Replace T7 source-shape checks where behavior coverage exists | T7 tests | T7 tests still protect timeouts, helper lookup, DiskArbitration safety |
| R21 | Todo | Medium | Keep minimal source guardrails for untestable platform constraints | Test suite | Remaining source checks are documented and intentionally narrow |

## Wave 6: Reminder and Pet Interaction Cleanup

| ID | Status | Risk | Task | Targets | Verification |
| --- | --- | --- | --- | --- | --- |
| R22 | Done | Medium | Extract shared reminder presentation/panel helpers | Hydration, seven-minute, sleep, intervention controllers | `MalDaze/TransientOverlay/` presenter + migrated hydration/center-bell/smart-reminder paths; see `extract-transient-overlay-presenter` |
| R23 | Todo | Medium-High | Extract PetStageView hit-test and interaction policies | `PetStageView`, WindowManager policies | Tests cover idle/rest/breakRun hit behavior where possible |
| R24 | Todo | Medium | Review stale code maps and align them with current architecture | `docs/*CODE_MAP.md` | Docs no longer describe obsolete behavior or tick rates |

## Execution Rules

- Run `git status --short --branch` before each implementation task.
- Use the current checkout by default unless the task is risky enough to justify a worktree.
- For non-worktree apply work, create a checkpoint commit before implementation.
- Follow RED -> GREEN -> REFACTOR for behavior changes.
- Do not remove source-inspection assertions until equivalent coverage exists or the assertion is explicitly retained as a narrow guardrail.
- Update this todo and the audit after each completed refactor task.
- Keep Hermes as SSOT. Do not add client-side suppression, optimistic hiding, shadow lists, or local filters.
