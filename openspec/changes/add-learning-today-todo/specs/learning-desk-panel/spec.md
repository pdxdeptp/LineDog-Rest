## ADDED Requirements

### Requirement: Today tab displays local today todo section

The learning desk panel today tab SHALL render a **今日 todo** section between the Hermes pending task list and the tomorrow preview block (when present). This section SHALL be sourced only from MalDaze local `today-todo.json` and SHALL remain visually and operationally separate from Hermes learning tasks and from the left-column EventKit plan.

#### Scenario: Section placement on loaded today view
- **WHEN** the today tab successfully loads Hermes tasks
- **THEN** the **今日 todo** section appears below the Hermes task list
- **AND** above the tomorrow preview when tomorrow preview is shown

#### Scenario: Section visible on empty Hermes day
- **WHEN** the today tab shows no Hermes pending tasks
- **THEN** the **今日 todo** section still renders when local data is available

#### Scenario: Distinct from Hermes insert
- **WHEN** the user adds a today todo entry
- **THEN** MalDaze does not open the Hermes insert-task sheet
- **AND** does not require project, duration, or Hermes task id

## MODIFIED Requirements

### Requirement: Learning panel error and empty states

The learning desk panel SHALL present explicit empty and error states when Hermes is unavailable or today has no work, while keeping the local **今日 todo** section usable when its JSON store is readable.

#### Scenario: Hermes script missing
- **WHEN** `schedule.py` cannot be executed
- **THEN** the middle column shows an error card with remediation guidance
- **AND** left reminder and right desk-pet controls remain usable
- **AND** the **今日 todo** section remains usable when `today-todo.json` is readable

#### Scenario: No pending tasks on a work day
- **WHEN** `pending_count` is zero and `is_rest_day` is false
- **THEN** the panel shows a no-tasks-today empty state for Hermes tasks
- **AND** still renders the **今日 todo** section when applicable

### Requirement: Dashboard learning panel displays today view

MalDaze SHALL present a learning desk panel in the Dashboard middle column that shows today's pending learning tasks by invoking Hermes `schedule.py rollover` followed by `schedule.py today` with `HERMES_HOME` set to the user's Hermes home directory.

#### Scenario: Open dashboard loads today list
- **WHEN** the user opens the desk pet Dashboard panel
- **THEN** MalDaze runs `schedule.py rollover` and `schedule.py today`
- **AND** the middle column renders pending tasks consistent with the `today` JSON output
- **AND** the panel does not read Feishu calendar as a task source
- **AND** MalDaze loads the local **今日 todo** section independently of the Hermes CLI result

#### Scenario: Manual refresh
- **WHEN** the user taps the learning panel refresh control
- **THEN** MalDaze re-runs `rollover` and `today`
- **AND** the displayed Hermes list updates to match the latest JSON
- **AND** MalDaze does not reload or mutate `today-todo.json` solely because of that refresh
