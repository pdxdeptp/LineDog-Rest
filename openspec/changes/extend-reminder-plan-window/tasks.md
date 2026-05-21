## 1. Reminder Window Tests

- [x] 1.1 Add a source-level or unit test proving the EventKit sidebar fetch uses a three-month forward window rather than a seven-day window.
- [x] 1.2 Update reminder sidebar merge/formatting test names or expectations so they no longer encode "week" as the displayed upcoming range.

## 2. Frontend Implementation

- [x] 2.1 Change the production EventKit reminder fetch horizon from seven days to three months using a named policy constant.
- [x] 2.2 Update user-facing "计划" sidebar copy and empty-state wording to describe the three-month window.
- [x] 2.3 Keep overdue reminders, today's `#日常` reminders, selected-list filtering, grouping, sorting, editing, postponing, deleting, and completion behavior unchanged.

## 3. Verification

- [x] 3.1 Run the relevant MalDaze reminder/sidebar tests.
- [x] 3.2 Validate the OpenSpec change artifacts and update this task list with completed checkboxes.
- [x] 3.3 Tell the user how to manually verify the desktop Dashboard "计划" sidebar after restarting the app.
