# hermes-day-reminders Specification

## Purpose

Hermes end-to-end Apple Reminders for day todos (create, list, complete, postpone, delete) aligned with MalDaze selected list; no MalDaze write path.
## Requirements
### Requirement: Hermes end-to-end day reminder management

Hermes SHALL manage Apple Reminders for day-todo items without MalDaze collaboration. Day-todo creation, completion, postponement, and deletion SHALL be initiated from Feishu conversation and executed on the local Mac through Hermes scripts or skill tooling.

#### Scenario: Create reminder from Feishu
- **WHEN** the user asks Hermes in Feishu to add a day todo such as going to the bank tomorrow afternoon
- **THEN** Hermes writes the reminder into Apple Reminders
- **AND** MalDaze is not required in the write path

#### Scenario: Complete reminder from Feishu
- **WHEN** the user tells Hermes that a named day todo is done
- **THEN** Hermes marks the matching Apple Reminder complete
- **AND** the result is reported back in Feishu

### Requirement: No MalDaze EventKit queue

The day-reminders capability SHALL NOT define or use a Hermes-to-MalDaze reminder mutation file contract. MalDaze SHALL NOT be the executor for Hermes day-todo writes.

#### Scenario: No cross-app write queue
- **WHEN** Hermes creates a day todo
- **THEN** Hermes does not write a MalDaze consumption queue under `data/maldaze/`
- **AND** only Apple Reminders remains the SSOT for day todos

### Requirement: Local write mechanism documentation

Hermes SHALL document the chosen local Apple Reminders write mechanism (`remindctl`, `osascript`, or approved alternative) including permission setup and failure messages.

#### Scenario: Documented write failure
- **WHEN** the local write mechanism fails due to permissions or invalid input
- **THEN** Hermes returns an explicit Feishu-visible error
- **AND** no silent success is reported

### Requirement: Reminder list aligned with MalDaze dashboard

Hermes SHALL write new day todos into the same Apple Reminders list that MalDaze uses in its dashboard sidebar, by reading `MalDaze.remindersSelectedCalendarIdentifier` from the `com.maldaze.MalDaze` UserDefaults domain when present, and otherwise applying the same default-list resolution order as MalDaze (`提醒事项`, `Reminders`, then first writable list).

#### Scenario: Uses desk pet selected list
- **WHEN** `MalDaze.remindersSelectedCalendarIdentifier` is set in UserDefaults
- **THEN** Hermes writes new reminders into that calendar
- **AND** the user sees the same items in the MalDaze dashboard and on iCloud-synced devices

#### Scenario: Falls back when desk pet has not selected a list
- **WHEN** the UserDefaults key is absent
- **THEN** Hermes resolves the default reminders list using the MalDaze-equivalent fallback order
- **AND** documents that selecting a list once in the desk pet dashboard aligns future Hermes writes

### Requirement: Single create without confirmation

Hermes SHALL create a single day todo from Feishu conversation without an extra confirmation step when the user intent is one reminder with unambiguous fields.

#### Scenario: Single reminder immediate create
- **WHEN** the user asks to add one clear day todo
- **THEN** Hermes writes the reminder immediately
- **AND** reports success in Feishu

### Requirement: Batch or recurrence requires confirmation

Hermes SHALL require explicit user confirmation before creating multiple reminders or reminders with recurrence rules in one operation.

#### Scenario: Batch create preview
- **WHEN** the parsed intent contains multiple reminders or a recurrence rule
- **THEN** Hermes shows a preview in Feishu
- **AND** writes only after the user confirms

### Requirement: MalDaze dashboard remains optional glance only

MalDaze MAY continue to show EventKit reminders in the dashboard sidebar for one-click complete actions, but that sidebar SHALL NOT be the primary creation path after this capability is available.

#### Scenario: Primary creation path is Hermes
- **WHEN** day-reminders skill is active
- **THEN** product documentation identifies Feishu Hermes as the primary day-todo creation entry
- **AND** MalDaze Smart Input is documented as legacy fallback only

