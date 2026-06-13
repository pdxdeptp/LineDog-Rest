## Why

MalDaze has accumulated several high-coupling centers where UI state, settings persistence, NotificationCenter commands, window orchestration, Hermes file contracts, and reminder controllers interact implicitly. Small changes can therefore miss a dependent path and require repeated manual investigation.

This change creates a documented refactor roadmap and an incremental implementation plan so the system can be decomposed safely without breaking current user-visible behavior or Hermes SSOT boundaries.

## What Changes

- Add a project-level coupling audit that maps the current high-risk architecture hotspots and their concrete evidence.
- Add a maintained refactor todo that orders work from low-risk infrastructure de-duplication to higher-risk coordinator and window boundary extraction.
- Introduce a core-boundary stabilization spec that requires each refactor step to preserve existing behavior, protect Hermes contracts, and leave stronger tests behind.
- Establish a staged refactor sequence for:
  - shared file-watcher infrastructure
  - shortcut registration and persistence
  - Hermes process/contract runtime boundaries
  - AppViewModel coordinator extraction
  - WindowManager window-controller extraction
  - source-inspection test migration
- Do not introduce breaking user-facing behavior changes in this change.

## Capabilities

### New Capabilities

- `core-boundary-stabilization`: Defines how MalDaze documents coupling hotspots, maintains the refactor todo, and performs incremental behavior-preserving refactors across core boundaries.

### Modified Capabilities

- None. This change adds refactor governance and implementation constraints; existing product capability requirements remain unchanged unless a later task discovers a required spec correction.

## Impact

- Affected documentation:
  - `docs/refactoring/system-coupling-audit.md`
  - `docs/refactoring/refactor-todo.md`
- Affected OpenSpec artifacts:
  - `openspec/changes/stabilize-core-boundaries/`
  - `openspec/specs/core-boundary-stabilization/spec.md` after archive
- Likely affected code during later implementation tasks:
  - `MalDaze/AppViewModel.swift`
  - `MalDaze/WindowManager/WindowManager.swift`
  - `MalDaze/DashboardRootView.swift`
  - `MalDaze/Settings/MalDazeSettingsView.swift`
  - Hermes contract readers, CLI wrappers, and file watchers
  - shortcut models and Carbon hotkey registration
  - tests that currently inspect source implementation details
- No external API or Hermes JSON contract changes are intended.
