## 1. Reminder Notes Data Flow

- [ ] 1.1 Add a failing test proving `ReminderDisplayItem` / EventKit sidebar mapping preserves user-facing notes while stripping standalone `#日常`.
- [ ] 1.2 Implement the minimal reminder display data change to carry plain notes into the sidebar item.

## 2. Sidebar Rendering

- [ ] 2.1 Add a failing presentation test proving the Dashboard reminder row renders non-empty notes under the title and omits an empty notes line.
- [ ] 2.2 Update the Dashboard reminder row UI to show notes as compact secondary detail text without changing due-time or action controls.

## 3. Verification

- [ ] 3.1 Run focused Swift tests for reminder mapping and Dashboard presentation.
- [ ] 3.2 Run OpenSpec validation/status for `restore-reminder-sidebar-notes`.
