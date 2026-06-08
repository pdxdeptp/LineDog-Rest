# hermes-learning-calendar Specification

## Purpose

Learning tasks remain SSOT in `projects.json`; Feishu calendar is optional all-day projection with delete-on-complete default.
## Requirements
### Requirement: Learning task SSOT remains projects.json

Learning tasks SHALL remain authoritative in `~/.hermes/data/learning-assistant/projects.json`. Feishu calendar events SHALL be optional projections and SHALL NOT become the SSOT for completion state.

#### Scenario: Complete updates JSON first
- **WHEN** Hermes completes learning task `task_3`
- **THEN** `projects.json` records `status: completed` for that task
- **AND** calendar projection updates are secondary to JSON state

### Requirement: All-day soft calendar anchors

When calendar projection is enabled, new learning events SHALL be created as all-day soft anchors on `scheduled_date` without requiring a specific clock time block.

#### Scenario: All-day event creation
- **WHEN** Hermes plans or moves a learning task with `scheduled_date` set
- **THEN** the projected Feishu event represents that date as an all-day anchor
- **AND** the event does not imply a fixed hour-by-hour study schedule

### Requirement: Calendar behavior on complete defaults to delete

By default, when a learning task is completed and calendar projection is enabled, Hermes SHALL delete the associated Feishu calendar event. Profile setting `calendar_on_complete` MAY override this default with `checkmark` or `none`. Calendar deletion SHALL NOT remove completed-task history from local JSON files.

#### Scenario: Default delete on complete
- **WHEN** `calendar_on_complete` is unset or `delete`
- **AND** Hermes completes a task that has `feishu_event_id`
- **THEN** Hermes deletes the Feishu event via user-identity calendar tooling
- **AND** the task record clears or nulls `feishu_event_id`
- **AND** `projects.json` retains the task with `status: completed` and `daily_log.json` retains the completion entry

### Requirement: Local JSON files retain full learning history

Hermes SHALL treat `projects.json` and `daily_log.json` as the durable history SSOT. Completing a task or deleting its Feishu calendar projection SHALL NOT purge historical task records needed for later review.

#### Scenario: History survives calendar delete
- **WHEN** a completed task's Feishu event is deleted
- **THEN** the task remains queryable in `projects.json` with completed status
- **AND** the completion remains recorded in `daily_log.json` for that date

#### Scenario: Checkmark override
- **WHEN** `calendar_on_complete` is `checkmark`
- **THEN** Hermes patches the event summary with a completion marker instead of deleting

### Requirement: Completion interaction is Feishu conversation

Users SHALL complete learning tasks through Feishu conversation with Hermes using `schedule.py complete` or equivalent skill commands. The Feishu calendar app UI SHALL NOT be required to provide a completion button.

#### Scenario: Today list then complete by id
- **WHEN** the user asks for today's learning tasks in Feishu
- **THEN** Hermes lists pending tasks with identifiable task ids
- **AND** the user can complete a task by referring to that id in the same conversation

### Requirement: Learning tasks are not migrated to Apple Reminders

Hermes SHALL NOT migrate learning tasks into Apple Reminders as a replacement for `projects.json` task semantics including review chains, move, remove, and capacity scheduling.

#### Scenario: No learning-to-reminders migration
- **WHEN** a learning task is planned or completed
- **THEN** Hermes does not create a parallel Apple Reminder representing that learning task
- **AND** learning scheduling semantics remain in the learning assistant data model

