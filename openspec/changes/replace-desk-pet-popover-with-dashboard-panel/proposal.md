## Why

The desk pet entry has outgrown `NSPopover`: it now opens a wide, multi-column dashboard with learning state, reminders, and controls rather than a small contextual menu. With the menu bar entry split into a compact settings launcher, the desk pet no longer needs to share menu bar popover semantics and can use a dedicated `NSPanel` dashboard that is faster to show, easier to keep warm, and better aligned with the product experience.

## Affected Specs

- `desk-pet-controls`
- `assistant-panel-ui`

## What Changes

- Replace the desk pet left-click control surface from an `NSPopover` to a dedicated `NSPanel` dashboard.
- Keep the dashboard visually lightweight and desk-pet-adjacent, but remove popover-specific behavior such as the arrow, `NSPopover.show(...)` timing, and popover cooldown semantics.
- Introduce a long-lived dashboard panel/controller lifecycle so the panel, SwiftUI host, and relevant dashboard state can be reused after first creation.
- Preserve the existing wide three-column dashboard concept: reminders, learning assistant, and timer/pet controls.
- Show cached dashboard content immediately when available and refresh in the background instead of forcing the learning assistant column through a gray startup state on every open.
- Keep desk pet toggle, outside click, Esc, and app deactivation behavior explicit and owned by the dashboard panel controller.
- Do not change the already-split menu bar settings entry in this change.

## Capabilities

### New Capabilities

- None

### Modified Capabilities

- `desk-pet-controls`: Desk pet left-click opens and manages a dedicated `NSPanel` dashboard instead of an `NSPopover`.
- `assistant-panel-ui`: The wide dashboard is hosted in a reusable panel context with cached-content startup behavior and background refresh expectations.

## Impact

- `MalDaze/WindowManager/WindowManager.swift`: replace desk pet popover creation/show/dismiss paths with a dashboard `NSPanel` controller or equivalent helper.
- `MalDaze/MenuBarContentView.swift`: likely rename or split the current shared control panel surface into a desk-pet dashboard root while preserving reusable child controls.
- `MalDaze/LearningAssistant/AssistantPanelView.swift`: continue rendering the learning assistant column, but participate in cached dashboard startup and refresh behavior.
- `MalDaze/LearningAssistant/LearningAssistantViewModel.swift`: likely move toward a longer-lived model or coordinator-owned instance so dashboard state survives panel hide/show.
- `MalDazeTests/ControlPanelPresentationTests.swift`: update source-level assertions from `NSPopover` requirements to `NSPanel` dashboard requirements.
- Manual QA: verify first open, repeated open, outside click, Esc, app deactivation, keyboard input, cached content, and backend offline/startup states from the desk pet entry.
