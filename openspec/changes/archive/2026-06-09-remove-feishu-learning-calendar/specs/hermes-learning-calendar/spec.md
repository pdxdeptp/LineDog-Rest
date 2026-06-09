## MODIFIED Requirements

### Requirement: Learning task SSOT remains projects.json

Learning tasks SHALL remain authoritative in `~/.hermes/data/learning-assistant/projects.json`. Hermes SHALL NOT project learning tasks to Feishu calendar or any external calendar as part of `schedule.py`.

#### Scenario: Complete updates JSON only
- **WHEN** Hermes completes learning task `task_3`
- **THEN** `projects.json` records `status: completed` for that task
- **AND** `schedule.py` does not call external calendar APIs

### Requirement: Completion interaction via conversation or desk panel

Users SHALL complete learning tasks through Feishu or Hermes conversation using `schedule.py complete`, or through the MalDaze learning desk panel spawning the same command.

#### Scenario: Complete from MalDaze desk panel
- **WHEN** the user completes a task from the MalDaze learning desk panel
- **THEN** MalDaze invokes `schedule.py complete --task-id <id>` with `HERMES_HOME` set
- **AND** `projects.json` records `status: completed` for that task

## REMOVED Requirements

### Requirement: All-day soft calendar anchors

**Reason**: Feishu calendar projection removed entirely.

### Requirement: Calendar behavior on complete defaults to delete

**Reason**: No calendar projection.

### Requirement: Rollover syncs Feishu calendar projection

**Reason**: No calendar projection.

#### Scenario: Rolled task updates calendar date

**Reason**: No calendar projection.

#### Scenario: Calendar patch failure does not block rollover

**Reason**: No calendar projection.
