## MODIFIED Requirements

### Requirement: Move task dates from panel via Hermes CLI

MalDaze SHALL postpone or reschedule tasks by spawning `schedule.py move --task-id <id> --new-date <YYYY-MM-DD>` and SHALL show a confirmation step that includes cascade impact before applying the move when dry-run preview is available.

When the user chooses a custom reschedule date from a task row, MalDaze SHALL present `ScrollMonthDatePicker` in a popover anchored to the row's overflow control within the Dashboard panel, and SHALL NOT embed the date picker inside a `Menu` or open a new centered modal solely for date selection.

#### Scenario: Postpone to tomorrow

- **WHEN** the user chooses postpone-to-tomorrow on a task row
- **THEN** MalDaze computes tomorrow's local date
- **AND** presents cascade preview when `move --dry-run` is available
- **AND** applies `move` only after user confirmation

#### Scenario: Pick custom date from popover

- **WHEN** the user chooses pick-date from a task row overflow menu
- **THEN** MalDaze opens a popover anchored to that row's overflow control
- **AND** the popover contains `ScrollMonthDatePicker` with trackpad or wheel month scrolling
- **AND** selecting a day closes the popover and starts the existing move preview flow for that ISO date

#### Scenario: Move rejected by Hermes

- **WHEN** `move` rejects the operation such as moving before today or cascade into the past
- **THEN** the panel displays the Hermes error message
- **AND** MalDaze does not apply local date changes in Swift

### Requirement: Insert and remove tasks from panel

MalDaze SHALL support `schedule.py insert` and `schedule.py remove` from the panel with confirmation on remove.

The insert-task sheet SHALL use `ScrollMonthDatePicker` inline inside the existing sheet form for choosing the task date, and SHALL NOT use the system graphical or compact `DatePicker` for the date field.

#### Scenario: Remove task with confirmation

- **WHEN** the user deletes a task from the today or schedule agenda
- **THEN** MalDaze shows a confirmation dialog before invoking `schedule.py remove`

#### Scenario: Insert task date picker in existing sheet

- **WHEN** the user opens the insert-task sheet with at least one active project
- **THEN** MalDaze shows the existing insert sheet chrome unchanged
- **AND** the date field is `ScrollMonthDatePicker` embedded in the form
- **AND** submitting still invokes `schedule.py insert` with the chosen ISO date

### Requirement: Edit active project deadline from project tab

MalDaze SHALL allow users to change an active project's deadline from the project overview tab by spawning `schedule.py set-deadline --project-id <id> --deadline <YYYY-MM-DD>` after explicit confirmation. By default Hermes SHALL repack incomplete project tasks.

The deadline edit sheet SHALL use the shared `ScrollMonthDatePicker` component with trackpad or wheel month scrolling. Double-clicking a day SHALL confirm when confirmation is allowed, matching the deadline-edit sheet rules already shipped in the pilot.

#### Scenario: Edit deadline on active project

- **WHEN** the user changes the deadline for an active project and confirms
- **THEN** MalDaze runs `schedule.py set-deadline` with the project id and new deadline
- **AND** on success refreshes project status, today, and schedule data as needed

#### Scenario: Deadline edit opens a single sheet with scroll-month picker

- **WHEN** the user activates the bordered deadline edit control on an active project
- **THEN** MalDaze opens one sheet with the scroll-month date picker bound to the current deadline (or today when unset)
- **AND** the sheet provides explicit cancel and confirm actions
- **AND** changing the selected date triggers the existing dry-run repack preview when applicable

#### Scenario: Scroll-month picker supports trackpad and wheel month navigation

- **WHEN** the deadline edit sheet is visible
- **THEN** the user can scroll vertically through consecutive month blocks to reach a target month
- **AND** scrolling snaps to whole month blocks on supported macOS versions
- **AND** tapping a day updates the selected deadline date shown in the sheet

#### Scenario: Repack overflow feedback

- **WHEN** `set-deadline` succeeds with `overflow_count` greater than zero
- **THEN** the panel shows a visible notice that some tasks could not fit before the new deadline
