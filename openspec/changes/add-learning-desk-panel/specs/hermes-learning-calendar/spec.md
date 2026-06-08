## MODIFIED Requirements

### Requirement: Completion interaction is Feishu conversation

Users SHALL complete learning tasks through Feishu conversation with Hermes using `schedule.py complete` or equivalent skill commands, or through the MalDaze learning desk panel spawning the same `schedule.py complete` command. The Feishu calendar app UI SHALL NOT be required to provide a completion button.

#### Scenario: Today list then complete by id in Feishu
- **WHEN** the user asks for today's learning tasks in Feishu
- **THEN** Hermes lists pending tasks with identifiable task ids
- **AND** the user can complete a task by referring to that id in the same conversation

#### Scenario: Complete from MalDaze desk panel
- **WHEN** the user completes a task from the MalDaze learning desk panel
- **THEN** MalDaze invokes `schedule.py complete --task-id <id>` with `HERMES_HOME` set
- **AND** `projects.json` records `status: completed` for that task
- **AND** calendar projection behavior matches the Feishu completion path for the same task id

## ADDED Requirements

### Requirement: Move dry-run preview for desk panel

Hermes `schedule.py move` SHALL support a dry-run mode that returns the planned `changes[]` cascade without persisting date updates, so MalDaze can show move preview before apply.

#### Scenario: Dry-run returns cascade only
- **WHEN** MalDaze invokes `schedule.py move --task-id <id> --new-date <date> --dry-run`
- **THEN** Hermes prints JSON containing `changes[]` for the target and cascaded same-project tasks
- **AND** `projects.json` scheduled dates remain unchanged

#### Scenario: Apply move after preview
- **WHEN** MalDaze invokes `move` without `--dry-run` after user confirmation
- **THEN** Hermes persists the same changes that dry-run previewed for equivalent inputs
