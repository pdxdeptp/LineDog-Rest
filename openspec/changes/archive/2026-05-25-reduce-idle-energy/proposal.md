## Why

MalDaze idle desktop pet currently keeps the UI layer awake through several polling timers even when the pet is visually static. Short runtime sampling showed no busy loop, but did show persistent timer wakeups from cursor tracking and the automatic rest watcher, with additional higher-cost paths during break-run, fullscreen rest, GIF playback, and eager assistant backend startup.

This change reduces idle CPU wakeups and battery impact while preserving the existing desktop pet interactions, rest interruption flows, and learning assistant behavior.

## Affected Specs

- `desk-pet-windowing`
- `pet-visuals`
- `break-interruption`
- `assistant-panel-ui`

## What Changes

- Replace or throttle always-on idle cursor polling so the transparent pet window still passes through clicks outside the pet hit area without waking the main run loop at 10 Hz forever.
- Change automatic rest watching from a 4 Hz polling loop to anchor-based scheduling while retaining per-second rest countdown updates.
- Reduce break-run movement cost by lowering the default frame rate and keeping motion time-based so speed remains stable.
- Reduce fullscreen rest redraws after the approach animation settles while preserving countdown behavior.
- Cache decoded GIF frames and avoid repeated decoding when animation intensity or pet mode changes.
- Add a user setting for local learning assistant backend startup mode: lazy startup when the assistant UI needs it, or eager startup at app launch for users who prefer lower first-open latency.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `desk-pet-windowing`: Idle mouse pass-through must avoid continuous high-frequency polling when the pet is static or the pointer is outside the hit area.
- `pet-visuals`: GIF frame decoding must be reused for static and intermediate animation paths so animation controls do not repeatedly decode the same asset.
- `break-interruption`: Automatic rest waiting and break-run/fullscreen rest animation timers must use lower-wakeup scheduling while preserving existing visual and timing behavior.
- `assistant-panel-ui`: The learning assistant backend startup mode must be user-configurable; lazy mode starts on assistant UI activation, eager mode starts at app launch, and the panel must still show connecting/offline/ready states correctly.

## Impact

- Affected Swift/AppKit UI code:
  - `MalDaze/WindowManager/WindowManager.swift`
  - `MalDaze/WindowManager/BreakRunController.swift`
  - `MalDaze/WindowManager/PetStageView.swift`
  - `MalDaze/PetRenderer/PetRenderer.swift`
  - `MalDaze/TimerEngine/AutoTimerEngine.swift`
  - `MalDaze/LearningAssistant/BackendProcessManager.swift`
  - `MalDaze/MalDazeAppDelegate.swift`
  - `MalDaze/LearningAssistant/LearningAssistantViewModel.swift`
  - `MalDaze/Settings/MalDazeSettingsView.swift`
  - `MalDaze/MalDazeDefaults.swift`
- Affected tests:
  - Timer scheduling and state transition tests
  - Backend lifecycle tests
  - Pet renderer behavior tests
  - Source-level or focused tests for idle cursor tracking and break-run frame rate
- No external API or dependency changes are expected.
