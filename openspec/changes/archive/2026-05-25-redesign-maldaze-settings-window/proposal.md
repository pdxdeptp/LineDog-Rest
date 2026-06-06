## Why

The settings window opened from the Dashboard right-column gear currently feels like an uncurated macOS form dump: retired-feature keys, smart-input Gemini settings, backend startup behavior, and shortcut recorders all compete at the same visual level. API key entry in particular is primitive, with raw secure fields and little state, provider context, or confidence that the secret is handled locally.

This change redesigns the settings experience so it feels like a polished MalDaze control surface: structured, calm, scannable, and trustworthy while preserving the existing local persistence and shortcut behavior.

## What Changes

- Replace the single grouped `Form` stack with a designed settings window shell that separates categories, detail content, and status/helper information.
- Redesign API key input rows for the retired-feature backend providers and Smart Input Gemini key with visible labels, provider-aware copy, saved/empty state, show/hide affordance, and local-only reassurance.
- Group provider/model selection, API key entry, backend lazy startup, Smart Input configuration, and shortcut recorders into clear sections or tabs without removing any existing capability.
- Improve shortcut rows with consistent keycap styling, primary/secondary actions, recording state feedback, and preserved Esc cancellation behavior.
- Resize the independent settings window to match the new layout instead of constraining it to the current small raw-form frame.
- Preserve all existing `@AppStorage` keys, model catalogs, global shortcut recording semantics, and backend startup semantics.

## Affected Specs

- `desk-pet-controls`

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `desk-pet-controls`: Add requirements for the MalDaze settings window launched from the Dashboard settings gear, including category hierarchy, API key entry quality, shortcut recording presentation, accessibility, and behavior preservation.

## Impact

- Affected SwiftUI/AppKit code:
  - `MalDaze/Settings/MalDazeSettingsView.swift`
  - Potentially tightly scoped settings helper views in the same file or a sibling under `MalDaze/Settings/`
  - `MalDazeSettingsWindowPresenter` sizing for the independent settings window
- Affected tests:
  - Swift/XCTest coverage for settings view structure, key labels, persistence identifiers, and shortcut controls where feasible.
  - Existing shortcut/window tests should remain green.
- No backend API changes.
- No new external dependencies.
- No persistence key migration.
