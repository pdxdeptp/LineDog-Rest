## Why

The Dashboard right controls column currently stacks timer, reminder, pet, hydration, test, and quit actions with similar visual weight. That makes the panel feel noisy and primitive, and it slows down the everyday path of checking status and starting or stopping common actions.

## What Changes

- Redesign the right controls column around a clear hierarchy: status summary, primary quick actions, compact settings, and low-priority utility actions.
- Replace the current uniform stack of section boxes with a calmer control surface that uses grouped rows, icon-led affordances, segmented controls, and progressive disclosure.
- Keep the existing capabilities and behavior intact: timer modes, start/stop/resume, rest behavior, pet appearance controls, countdown reminder, hydration reminder, cat companion, settings, and quit.
- Add a static HTML design preview before SwiftUI implementation so the visual direction can be reviewed without changing production UI code.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `desk-pet-controls`: The Dashboard right controls column SHALL present the existing controls with a clearer visual hierarchy, accessible targets, and lower visual noise.

## Impact

- Affected production UI will be concentrated in `MalDaze/DashboardRootView.swift`.
- Existing `AppViewModel`, defaults keys, timer engines, reminders, hydration, and cat companion logic should remain unchanged.
- Tests around Dashboard presentation and control behavior may need updates only if they assert view structure or labels.
- Static prototype lives under `openspec/changes/redesign-dashboard-controls-column/` and is not production app code.
