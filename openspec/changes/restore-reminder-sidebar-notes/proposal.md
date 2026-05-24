## Why

The Dashboard left "计划" sidebar currently renders reminder titles and times but drops the reminder notes before the row view can display them. This regresses the reminder-plan experience because notes often carry the actionable context that distinguishes otherwise short titles.

## What Changes

- Preserve plain reminder notes in the in-memory sidebar display item.
- Render non-empty notes as secondary text below each reminder title in the left plan sidebar.
- Continue stripping the standalone `#日常` marker from displayed notes while keeping the routine badge behavior.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `desk-pet-controls`: The Dashboard left reminder plan sidebar must show reminder note/details text when present.

## Impact

- Affected Swift UI: `MalDaze/DashboardRootView.swift`
- Affected reminder data mapping: `MalDaze/Reminders/ReminderDisplayItem.swift`, `MalDaze/Reminders/EventKitRemindersBacking.swift`, mocks/tests
- No backend, persistence, EventKit write contract, or dependency changes
