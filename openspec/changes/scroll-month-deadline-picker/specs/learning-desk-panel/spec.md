## MODIFIED Requirements

### Requirement: Edit active project deadline from project tab

MalDaze SHALL allow users to change an active project's deadline from the project overview tab by spawning `schedule.py set-deadline --project-id <id> --deadline <YYYY-MM-DD>` after explicit confirmation. By default Hermes SHALL repack incomplete project tasks.

The deadline edit sheet SHALL use MalDaze's scroll-month date picker (vertical continuous month list with scroll snap) instead of the system graphical `DatePicker`, so users can change months via trackpad or mouse wheel scrolling as well as by selecting a day in the grid.

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
- **AND** scrolling snaps to whole month blocks
- **AND** tapping a day updates the selected deadline date shown in the sheet

#### Scenario: Repack overflow feedback

- **WHEN** `set-deadline` succeeds with `overflow_count` greater than zero
- **THEN** the panel shows a visible notice that some tasks could not fit before the new deadline
