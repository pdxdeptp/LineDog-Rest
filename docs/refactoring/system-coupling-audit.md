# MalDaze System Coupling Audit

Last updated: 2026-06-13

This document records the current coupling hotspots that make MalDaze hard to change safely. It is intentionally evidence-based: each hotspot points to concrete files or code areas, then separates risk from the preferred refactor direction.

## Executive Summary

MalDaze's biggest maintainability risk is not a lack of local abstractions. The risk is that several "center" types coordinate too many unrelated lifecycle domains:

- `AppViewModel` is the application bus for timers, reminders, Hermes-backed features, T7, pet display mode, global shortcuts, settings synchronization, and window side effects.
- `WindowManager` is a window state machine for the idle pet, rest fullscreen, breakRun, dashboard, smart input, toast, cursor tracking, and screen observers.
- Dashboard and Settings views write `@AppStorage` directly, then depend on NotificationCenter or AppViewModel methods to synchronize runtime state.
- Hermes readers, CLI wrappers, and file watchers each encode their own path/runtime behavior instead of sharing a boundary layer.
- Many source-inspection tests protect historical regressions but also lock implementation shape, which makes refactors expensive.

The recommended path is staged: first extract duplicated infrastructure, then centralize settings/Hermes boundaries, then split `AppViewModel` and `WindowManager` behind stronger tests.

## Current Coupling Map

```text
SettingsView / DashboardRootView
    | direct @AppStorage writes
    | NotificationCenter posts
    v
AppViewModel
    | timer engines
    | reminder controllers
    | Hermes-backed orchestration
    | T7 UI bridge
    | pet display mode sync
    v
WindowManager
    | idle pet window
    | rest fullscreen
    | breakRun
    | dashboard window
    | smart input and toast panels
    v
NSWindow / UserDefaults / NotificationCenter / Hermes files and commands
```

## Hotspots

### P0: AppViewModel Is the Application Bus

Evidence:

- `MalDaze/AppViewModel.swift:81` through `MalDaze/AppViewModel.swift:97` owns timer engines, `WindowManaging`, smart reminder orchestration, seven-minute reminders, cat companion, hydration, sleep, intervention, and T7 services.
- `MalDaze/AppViewModel.swift:284` through `MalDaze/AppViewModel.swift:346` installs many NotificationCenter observers for global commands and settings changes.
- `MalDaze/AppViewModel.swift:399` through `MalDaze/AppViewModel.swift:407` reads and normalizes UserDefaults, then updates multiple timer engines.
- `MalDaze/AppViewModel.swift:608` through `MalDaze/AppViewModel.swift:689` mixes smart reminder UI callbacks, LLM orchestration, toast display, undo, and bell scheduling.
- `MalDaze/AppViewModel.swift:808` through `MalDaze/AppViewModel.swift:884` changes timer state while directly dismissing rest windows and syncing pet display.
- `MalDaze/AppViewModel.swift:1024` through `MalDaze/AppViewModel.swift:1050` maps timer/smart-reminder state to menu and idle pet display modes.

Risk:

- A small setting or UI change may require synchronized updates across timers, windows, pet state, and reminder controllers.
- Notification-based entry points make it easy to miss a path during refactors.
- Testing a single behavior requires large mocks because AppViewModel owns too many collaborators.

Refactor direction:

- Extract `TimerCoordinator` for manual/auto mode, suspended state, rest transitions, and status text.
- Extract `ReminderCoordinator` for hydration, sleep, intervention, seven-minute, and smart reminder bells.
- Extract `PetDisplayCoordinator` for mapping domain state to `PetDisplayMode`.
- Keep AppViewModel as composition root and published UI facade, not as the owner of all behavior.

### P0: WindowManager Owns Too Many Window State Machines

Evidence:

- `MalDaze/WindowManager/WindowManager.swift:127` through `MalDaze/WindowManager/WindowManager.swift:166` exposes a broad `WindowManaging` protocol covering rest, breakRun, pet display, smart input, dashboard, toast, reset, and settings application.
- `MalDaze/WindowManager/WindowManager.swift:213` through `MalDaze/WindowManager/WindowManager.swift:267` stores state for pet window, dashboard window, screen observers, cursor timers, breakRun, shield panels, smart input, and toast.
- `MalDaze/WindowManager/WindowManager.swift:421` through `MalDaze/WindowManager/WindowManager.swift:489` installs the pet window and screen observers, including historical ordering constraints.
- `MalDaze/WindowManager/WindowManager.swift:529` through `MalDaze/WindowManager/WindowManager.swift:665` handles rest and breakRun presentation.
- `MalDaze/WindowManager/WindowManager.swift:917` through `MalDaze/WindowManager/WindowManager.swift:989` owns cursor and mouse-event policy.
- `MalDaze/WindowManager/WindowManager.swift:1172` through `MalDaze/WindowManager/WindowManager.swift:1338` owns dashboard window lifecycle.

Risk:

- Window lifecycle and focus bugs are easy to reintroduce because unrelated panels share state in one object.
- Historical fixes are embedded as comments and source-shape tests rather than isolated policy objects.
- Manual QA burden is high for any edit.

Refactor direction:

- Extract policy-only structs first where possible: dashboard frame persistence, mouse-event policy, rest/breakRun transition policy.
- Then split controllers: `PetWindowController`, `DashboardWindowController`, `RestOverlayController`, `SmartInputPanelController`.
- Keep a thin `WindowManager` facade until tests and call sites no longer need the monolith.

### P0: Source-Inspection Tests Lock Implementation Shape

Evidence:

- `MalDazeTests/ControlPanelPresentationTests.swift` is currently 2047 lines and contains many `source.contains(...)` assertions.
- Source-inspection usage also appears in `T7DiskArbitrationEjectorTests`, `T7TimeMachineControllerTests`, `T7TargetResolverTests`, `T7EjectHelperRunnerTests`, `EnergyWakeupSourceTests`, and `T7EjectServiceTests`.
- Examples include checking exact symbols such as `makeDeskMenuWindowIfNeeded`, `installDashboardEscMonitor`, `GeometryReader`, `override var canBecomeMain`, and specific implementation tokens.

Risk:

- Moving code to better-named types can fail tests even if behavior is preserved.
- Refactors may either stall or weaken tests without equivalent behavior coverage.

Refactor direction:

- Inventory source-shape tests by the regression they protect.
- Before moving guarded code, add behavior, contract, or policy tests for the extracted responsibility.
- Keep only a small number of source-inspection guardrails for risks that cannot yet be tested directly.

### P1: Dashboard and Settings Are Runtime Configuration Surfaces

Evidence:

- `MalDaze/DashboardRootView.swift:480` through `MalDaze/DashboardRootView.swift:504` declares many `@AppStorage` settings for reminders, sleep, shortcuts, pomodoro, pet appearance, and dashboard layout.
- `MalDaze/DashboardRootView.swift:614` through `MalDaze/DashboardRootView.swift:695` composes reminders, learning, and controls in one large view.
- `MalDaze/DashboardRootView.swift:1003` through `MalDaze/DashboardRootView.swift:1085` binds controls directly to AppViewModel commands and stored settings.
- `MalDaze/Settings/MalDazeSettingsView.swift:7` through `MalDaze/Settings/MalDazeSettingsView.swift:38` repeats many `@AppStorage` entries for LLM, shortcuts, sleep, learning, and dashboard layout.
- `MalDaze/Settings/MalDazeSettingsView.swift:357`, `:418`, `:427`, `:436`, `:445`, and `:454` post NotificationCenter events after settings changes.

Risk:

- The same setting can be read and written from multiple places, then separately synchronized to runtime controllers.
- UI files carry migration and fallback logic that belongs to typed settings or services.

Refactor direction:

- Introduce typed settings domains such as `TimerSettings`, `ReminderSettings`, `PetAppearanceSettings`, `DashboardLayoutSettings`, and `SmartInputSettings`.
- Let views bind to these domains rather than directly coordinating side effects.
- Move notification emission into settings services or coordinators.

### P1: Hermes Boundary Is Duplicated

Evidence:

- `MalDaze/LearningDeskPanel/HermesScheduleCLI.swift:19` through `MalDaze/LearningDeskPanel/HermesScheduleCLI.swift:36` still owns the learning CLI wrapper and Python executable default, while Hermes home delegates to `HermesRuntimePaths`.
- `MalDaze/LearningDeskPanel/HermesScheduleCLI.swift:139` through `MalDaze/LearningDeskPanel/HermesScheduleCLI.swift:156` delegates project/script paths and process execution to shared Hermes runtime helpers.
- `MalDaze/NutritionToday/NutritionHermesCLI.swift:13` through `MalDaze/NutritionToday/NutritionHermesCLI.swift:33` still owns the nutrition CLI timeout and Python executable default, while Hermes home delegates to `HermesRuntimePaths`.
- `MalDaze/NutritionToday/NutritionHermesCLI.swift:46` through `MalDaze/NutritionToday/NutritionHermesCLI.swift:68` delegates script/data-directory paths and process execution to shared Hermes runtime helpers while preserving nutrition-specific timeout behavior.
- `MalDaze/HermesRuntime.swift:31` through `MalDaze/HermesRuntime.swift:45` now centralizes sleep schedule, intervention request, nutrition daily log, and nutrition recommendation JSON locations.
- `MalDaze/SleepReminder/SleepScheduleContract.swift:50` through `MalDaze/SleepReminder/SleepScheduleContract.swift:52`, `MalDaze/InterventionRequest/InterventionRequestContract.swift:48` through `MalDaze/InterventionRequest/InterventionRequestContract.swift:50`, `MalDaze/NutritionToday/NutritionDailyLogContract.swift:142` through `MalDaze/NutritionToday/NutritionDailyLogContract.swift:144`, and `MalDaze/NutritionToday/NutritionRecommendationContract.swift:185` through `MalDaze/NutritionToday/NutritionRecommendationContract.swift:187` delegate reader defaults to `HermesRuntimePaths`.

Risk:

- Inconsistent timeout behavior and error formatting still make Hermes failures harder to reason about.
- The project contract requires Hermes to remain the source of truth, but the boundary is spread across many files.

Refactor direction:

- Extract `HermesHome`, `HermesPathResolver`, and `HermesProcessRunner`.
- Keep per-domain readers and decoders, but inject shared path/runtime helpers.
- Preserve fail-loud contract behavior and avoid any local shadow state or optimistic filtering.

### P1: FSEvent File Watchers Are Nearly Identical

Evidence:

- `MalDaze/LearningDeskPanel/LearningProjectsFileWatcher.swift`
- `MalDaze/SleepReminder/SleepScheduleFileWatcher.swift`
- `MalDaze/NutritionToday/NutritionDailyLogFileWatcher.swift`
- `MalDaze/InterventionRequest/InterventionRequestFileWatcher.swift`

Each stores a directory path, watched filename, callback, `FSEventStreamRef`, the same flags, the same lifecycle, and nearly identical event filtering.

Risk:

- Bug fixes to FSEvents lifecycle or filtering must be copied to every watcher.
- Small per-domain differences can emerge accidentally.

Refactor direction:

- Create one `FileChangeWatcher` or `HermesFileWatcher`.
- Keep small domain wrappers only where a default URL improves readability.
- Add tests around event filtering if it can be isolated without real FSEvents.

### P1: Shortcut Models and Carbon Registration Are Duplicated

Evidence:

- `MalDaze/SmartReminderInputShortcut.swift`
- `MalDaze/DeskPetMenuShortcut.swift`
- `MalDaze/SevenMinuteReminderShortcut.swift`
- `MalDaze/ResetIdlePetPositionShortcut.swift`
- `MalDaze/MalDazeCarbonGlobalHotKeys.swift:67` through `MalDaze/MalDazeCarbonGlobalHotKeys.swift:140` begins repeated register/unregister/sync logic for each shortcut.

Risk:

- Adding or changing a shortcut requires updates across model, defaults, settings UI, dashboard UI, Carbon registration, and NotificationCenter callback handling.
- Disabled shortcut behavior and display formatting can drift.

Refactor direction:

- Introduce `GlobalShortcut` value type with defaults keys, display formatting, enablement, and event matching.
- Introduce `CarbonHotKeyRegistry` that registers descriptors in a table.
- Keep existing NotificationCenter names initially, then consider a typed command router later.

### P1: MalDazeDefaults Still Mixes Defaults Behavior, Policy, and Side Effects

Evidence:

- `MalDaze/MalDazeDefaultsKeys.swift:3` through `MalDaze/MalDazeDefaultsKeys.swift:108` now owns the UserDefaults key-string namespaces for smart input, legacy Gemini, shortcuts, timer, reminders, T7, sleep, pet appearance, dashboard, and learning.
- `MalDaze/MalDazeDefaults.swift:3` through `MalDaze/MalDazeDefaults.swift:153` preserves the existing `MalDazeDefaults.*` key API as compatibility aliases and keeps provider/default fallback resolvers.
- `MalDaze/MalDazeDefaults.swift:163` through `MalDaze/MalDazeDefaults.swift:180` still performs animation intensity migration and direct UserDefaults reads.
- `MalDaze/DashboardLayout.swift:3` through `MalDaze/DashboardLayout.swift:104` now owns dashboard column width and left-plan fraction policy in `DashboardLayout`; `MalDazeDefaults` keeps the old dashboard layout API names only as compatibility aliases/wrappers.
- `MalDaze/MalDazeDefaults.swift:264` through `MalDaze/MalDazeDefaults.swift:273` still writes learning capacity back to Hermes profile.

Risk:

- A global defaults facade still has provider fallback behavior, migration logic, and cross-system learning side effects even though raw key strings and dashboard layout policy have been split out.
- It encourages more unrelated settings to accumulate in one file.

Refactor direction:

- Keep the key namespace split stable and route new key strings through `MalDazeDefaultsKeys`.
- Keep dashboard layout policy in dashboard layout types while preserving existing defaults compatibility names.
- Move Hermes profile sync into an explicit learning settings sync service in R7.

### P2: Reminder Controllers Duplicate Timer, Panel, and Screen Observer Patterns

Evidence:

- `SleepReminderController`, `InterventionRequestController`, `HydrationReminderController`, and `SevenMinuteReminderController` each manage a mix of timers, reloads, panels, observers, and presentation details.
- Sleep has already moved some decision logic into `SleepReminderReconciler`, which is a healthier direction.

Risk:

- Each reminder type can fix lifecycle bugs differently.
- Panel positioning and screen-change handling can drift.

Refactor direction:

- Extract shared reminder presentation utilities after the Hermes/file-watcher and settings work.
- Preserve domain-specific scheduling logic in each controller.
- Prefer policy structs for quiet hours, due checks, and dedupe before moving NSPanel code.

### P2: PetStageView Still Mixes Rendering and Interaction State

Evidence:

- `MalDaze/WindowManager/PetStageView.swift` is 654 lines and participates in idle rendering, drag, rest animation, breakRun click counting, hit testing, and layout.
- BreakRun motion is already better isolated in `BreakRunController`, but the view still contains several mode-specific UI branches.

Risk:

- Rendering changes can accidentally alter hit testing or rest/breakRun behavior.
- WindowManager and PetStageView both participate in phase transitions.

Refactor direction:

- Keep visual rendering local, but extract hit-test and phase interaction policies where possible.
- Do this after WindowManager responsibilities are split enough to avoid simultaneous state-machine movement.

## Positive Existing Boundaries

These are useful patterns to preserve:

- Hermes learning uses a `HermesScheduleCLI` protocol, which makes the process boundary injectable.
- Sleep reminder has `SleepReminderReconciler`, a good model for extracting decision logic from controllers.
- T7 has multiple dedicated service/policy types and substantial tests, even though some tests still inspect source shape.
- Existing OpenSpec docs clearly state Hermes/MalDaze contract boundaries and SSOT expectations.

## Refactor Invariants

- Preserve current user-visible behavior unless an OpenSpec product spec is intentionally modified.
- Preserve Hermes JSON/command contracts as the source of truth.
- Do not add MalDaze-owned shadow lists, local suppression, optimistic hiding, or client-side filters to compensate for Hermes behavior.
- Prefer extracting pure policy first, then moving lifecycle code.
- Before changing high-risk window or coordinator code, create or strengthen focused tests.
- Update `docs/refactoring/refactor-todo.md` after each completed refactor step.
