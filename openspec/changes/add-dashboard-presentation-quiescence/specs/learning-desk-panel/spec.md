## MODIFIED Requirements

### Requirement: Dashboard learning panel displays today view

MalDaze SHALL present a learning desk panel in the Dashboard middle column that shows today's pending learning tasks by invoking Hermes `schedule.py rollover` followed by `schedule.py today` with `HERMES_HOME` set to the user's Hermes home directory.

#### Scenario: Open dashboard loads today list

- **WHEN** the user opens the desk pet Dashboard panel
- **THEN** MalDaze runs `schedule.py rollover` and `schedule.py today`
- **AND** the middle column renders pending tasks consistent with the `today` JSON output
- **AND** the panel does not read Feishu calendar as a task source

#### Scenario: Hide dashboard stops learning file watcher

- **WHEN** the Dashboard presentation phase becomes `hidden`
- **THEN** MalDaze stops the learning projects file watcher if it was started
- **AND** MalDaze may restart the watcher when the learning panel appears again after the Dashboard becomes visible
