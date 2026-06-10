## Why

Clicking a transient reminder overlay can activate MalDaze and unintentionally bring an already-open desk-pet Dashboard window to the front. Users expect handling a reminder to affect only that reminder, not to surface the Dashboard over their current desktop context.

## What Changes

- Make center bell reminder dismissal non-activating with respect to the rest of the app windows.
- Make hydration reminder actions non-activating with respect to the rest of the app windows.
- Preserve existing reminder content, placement, and actions.
- Ensure an already-visible Dashboard is not brought forward solely because the user handles a reminder.

## Capabilities

### New Capabilities

### Modified Capabilities
- `sleep-reminder`: Center bell reminders must dismiss without foregrounding the desk-pet Dashboard.
- `hydration-reminder`: Hydration reminder actions must not foreground the desk-pet Dashboard.

## Impact

- Affected code: `MalDaze/SevenMinuteReminder/SevenMinuteReminderController.swift`, `MalDaze/HydrationReminder/HydrationReminderController.swift`.
- Affected tests: focused source/behavior coverage in `MalDazeTests/ControlPanelPresentationTests.swift`.
- No changes to Hermes contracts, timer scheduling, reminder text, or Dashboard explicit open/focus entry points.
