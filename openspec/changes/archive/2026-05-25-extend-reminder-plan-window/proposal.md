## Why

The desk-pet Dashboard "计划" sidebar currently only fetches incomplete reminders through the next seven days. Users who rely on the sidebar for upcoming deadlines need a longer planning horizon so reminders scheduled beyond the current week remain visible without opening the system Reminders app.

## Affected Specs

- `desk-pet-controls`

## What Changes

- Expand the desk-pet Dashboard "计划" sidebar reminder window from the current seven-day horizon to the next three months.
- Keep overdue incomplete reminders and today's `#日常` reminders included as they are today.
- Update sidebar copy and empty-state wording so the visible range no longer claims "七日内".
- Preserve existing grouping, sorting, editing, postponing, deleting, and selected-list behavior.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `desk-pet-controls`: the shared desktop-pet/menu Dashboard plan sidebar shall show incomplete reminders due within the next three months instead of only within the next seven days.

## Impact

- Swift frontend EventKit reminder fetch window and sidebar copy.
- Reminder sidebar merge/formatting tests.
- No backend, API, database, dependency, or EventKit permission changes.
