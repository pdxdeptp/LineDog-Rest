## ADDED Requirements

### Requirement: Local JSON is the single source of truth

MalDaze SHALL persist today todo entries in `~/Library/Application Support/MalDaze/today-todo.json` as the only authoritative store for titles, completion state, assigned dates, and rollover metadata. MalDaze SHALL NOT write today todo data to EventKit, Hermes `projects.json`, or UserDefaults as a duplicate content store.

#### Scenario: Create entry writes JSON
- **WHEN** the user adds a non-empty title from the today todo input
- **THEN** MalDaze appends an entry with `dateISO` equal to the local calendar today
- **AND** atomically persists the updated file

#### Scenario: No external sync
- **WHEN** the user adds, completes, or deletes a today todo entry
- **THEN** MalDaze does not invoke EventKit or Hermes schedule commands for that entry

### Requirement: Incomplete entries roll forward to today

MalDaze SHALL roll incomplete today todo entries whose `dateISO` is before the local calendar today forward to today when the user opens or switches to the learning panel today tab.

#### Scenario: Roll on today tab load
- **WHEN** the today tab loads and one or more incomplete entries have `dateISO` earlier than today
- **THEN** MalDaze sets each such entry's `dateISO` to today
- **AND** sets `rolledFromDateISO` to the prior assigned date when it was not already set
- **AND** persists the updated file before rendering the today list

#### Scenario: Rolled entry visible in today list
- **WHEN** an entry was rolled forward from a prior date
- **THEN** it appears in the today todo incomplete list for today
- **AND** MAY show a visible rolled-from hint derived from `rolledFromDateISO`

### Requirement: Today tab section supports quick add and complete

The learning desk panel today tab SHALL render a **今日 todo** section below the Hermes task list with a scroll-following single-line input, checkbox completion, inline edit, and delete without confirmation dialog.

#### Scenario: Add with Enter
- **WHEN** the user types a non-empty trimmed title and submits the input (Return)
- **THEN** a new incomplete entry appears in the today todo section
- **AND** the input clears

#### Scenario: Complete retains strikethrough
- **WHEN** the user marks an entry complete
- **THEN** the entry remains in the today todo section under a collapsed completed group
- **AND** renders with strikethrough styling
- **AND** records `completedAt`

#### Scenario: Uncomplete restores incomplete list
- **WHEN** the user unchecks a completed entry
- **THEN** the entry returns to the incomplete list for today
- **AND** clears or nulls `completedAt` as appropriate

#### Scenario: Delete entry
- **WHEN** the user deletes an entry from the row menu
- **THEN** MalDaze removes it from JSON without a confirmation dialog

### Requirement: History sheet shows past completed entries

MalDaze SHALL provide a **历史** control on the today todo section that opens a sheet listing completed entries grouped by assigned `dateISO` in descending date order for dates before today.

#### Scenario: Open history
- **WHEN** the user taps **历史**
- **THEN** MalDaze presents a sheet of completed entries whose `dateISO` is before today
- **AND** groups them by date with most recent dates first

#### Scenario: Incomplete past entries excluded from history
- **WHEN** an incomplete entry existed on a prior date and was rolled to today
- **THEN** it does not appear in the history sheet
- **AND** appears only in today's main today todo list

### Requirement: Today todo is independent of Hermes budget and refresh

Today todo entries SHALL NOT affect Hermes study or review budget displays, and the learning panel Hermes refresh control SHALL NOT reload or mutate today todo data.

#### Scenario: Hermes refresh unchanged
- **WHEN** the user taps the learning panel refresh control on the today tab
- **THEN** MalDaze re-runs Hermes rollover and today as today
- **AND** does not re-read or rewrite `today-todo.json` solely because of that refresh

#### Scenario: Hermes failure still allows today todo
- **WHEN** Hermes today load fails
- **THEN** the today todo section remains usable if local JSON is readable
- **AND** Hermes error UI and today todo section may both be visible

#### Scenario: Empty title rejected
- **WHEN** the user submits whitespace-only input
- **THEN** MalDaze does not create an entry

### Requirement: Corrupt or missing file degrades gracefully

MalDaze SHALL surface a non-blocking error state in the today todo section when `today-todo.json` is missing required schema fields or cannot be decoded, and SHALL disable mutating controls until a valid file can be loaded or recreated.

#### Scenario: Decode failure
- **WHEN** `today-todo.json` cannot be decoded
- **THEN** the today todo section shows an error hint
- **AND** disables add/complete/delete actions
- **AND** does not prevent Hermes task rendering elsewhere in the panel
