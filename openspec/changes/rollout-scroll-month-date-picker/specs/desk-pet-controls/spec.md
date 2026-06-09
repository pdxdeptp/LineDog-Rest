## ADDED Requirements

### Requirement: Reminder edit sheet uses scroll-month date picker

The Dashboard left-column reminder edit sheet SHALL use the shared `ScrollMonthDatePicker` for choosing a due date when a due date is enabled. The sheet SHALL remain the same presentation surface as before; only the date control SHALL change. When the user enables an explicit due time, MalDaze SHALL keep a separate time control for hour and minute selection and SHALL NOT open an additional centered modal for date selection.

#### Scenario: Edit reminder due date inline in sheet

- **WHEN** the user opens edit on a reminder from the plan sidebar
- **THEN** MalDaze presents the existing reminder edit sheet
- **AND** the due-date section uses `ScrollMonthDatePicker` instead of the system date `DatePicker`
- **AND** saving still persists through the existing EventKit reminder edit path

#### Scenario: Reminder with explicit time keeps inline time picker

- **WHEN** the user toggles explicit due time on in the reminder edit sheet
- **THEN** the sheet shows scroll-month date selection and a compact time picker for hour and minute
- **AND** both values are written back into the same draft due date before save

#### Scenario: No due date toggle unchanged

- **WHEN** the user enables no due date on the reminder edit sheet
- **THEN** the scroll-month picker is hidden
- **AND** the sheet behavior matches the pre-rollout no-due-date flow
