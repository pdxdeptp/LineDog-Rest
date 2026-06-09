## ADDED Requirements

### Requirement: Today diagnostic action cards

When the today response indicates project behind warnings or either study or review bucket is over capacity, the learning desk panel SHALL show a compact diagnostic action card with navigation shortcuts. The panel SHALL NOT apply schedule mutations from these cards in default mode.

#### Scenario: Over capacity action card
- **WHEN** today's study or review minutes exceed the configured budget
- **THEN** the panel shows an action card naming the over-capacity condition
- **AND** offers a control to open the Schedule tab focused on tomorrow's date

#### Scenario: Behind warning action card
- **WHEN** `today.warnings` is non-empty
- **THEN** the panel lists behind projects in the action card
- **AND** offers a control to filter the today list to a selected `project_id` or open the Projects tab scrolled to that project card

#### Scenario: Repack from action card with confirmation
- **WHEN** the user chooses repack for a behind or selected project from the action card
- **THEN** MalDaze runs `schedule.py set-deadline` dry-run with the unchanged project deadline
- **AND** shows a preview of task moves and overflow before apply
- **AND** applies repack only after explicit user confirmation

#### Scenario: Warning row navigates to today task
- **WHEN** the user activates a behind-warning row in the today tab
- **THEN** MalDaze highlights the first pending task for that `project_id` in today's list when one exists
- **AND** shows a notice when no pending task exists for that project today

### Requirement: Tomorrow preview on today tab

The today tab SHALL show a read-only tomorrow preview sourced from the `today` response without requiring the user to open the Schedule tab.

#### Scenario: Tomorrow preview block
- **WHEN** `today.tomorrow_preview` is present
- **THEN** the today tab shows tomorrow's date, pending count, study minutes, and up to five preview task titles
- **AND** does not offer write actions in the preview block

### Requirement: Task source link on today rows

When a pending task's project has `source_url`, the today task row SHALL offer an external open action for that URL.

#### Scenario: Open source URL
- **WHEN** `pending[].source_url` is a non-empty string
- **THEN** the task row shows a link affordance
- **AND** activating it opens the URL with the system default browser
