## Why

Dashboard column resizing had been stable, but flicker returned after adding the plan/nutrition row resize separator and sharing the same AppKit resize handle across column and row separators. The regression aligns with a drag-coordinate change from stable window coordinates to handle-local coordinates, which can feed layout movement back into the next drag delta.

## What Changes

- Stabilize Dashboard resize-handle drag deltas for both column and row separators.
- Keep the existing AppKit-backed hit testing, tracking areas, and resize cursors.
- Preserve live resizing behavior for the left/right columns and the plan/nutrition split.
- Add regression coverage that prevents using moving handle-local coordinates for drag deltas.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `desk-pet-controls`: Dashboard resize separators must update smoothly without flickering while preserving resize cursor and drag behavior.

## Impact

- Affected code: `MalDaze/DashboardRootView.swift`
- Affected tests: `MalDazeTests/ControlPanelPresentationTests.swift`
- No API, Hermes contract, persistence key, or dependency changes.
