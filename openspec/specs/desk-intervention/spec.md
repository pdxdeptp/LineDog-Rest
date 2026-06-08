# desk-intervention Specification

## Purpose

MalDaze consumes Hermes `intervention_request.json` for on-screen strong reminders (bell, countdown, cancel). Feishu cooking timers use **cron wait + `kind: bell` at fire time** (see `docs/integrations/features/desk-intervention.md`); `countdown` remains for direct/script/local paths.
## Requirements
### Requirement: Intervention request lifecycle watching

MalDaze SHALL watch `intervention_request.json` and reload on application start, FSEvents change, workspace wake, and foreground activation, following the same reliability pattern as sleep schedule watching.

#### Scenario: File change triggers reload
- **WHEN** Hermes updates `intervention_request.json` while MalDaze is running
- **THEN** MalDaze reloads the contract within the file watcher debounce window
- **AND** MalDaze attempts execution if the payload is valid and unconsumed

#### Scenario: Startup processes unconsumed request
- **WHEN** MalDaze launches and a valid unconsumed pending request exists
- **THEN** MalDaze executes the request without requiring user action in MalDaze

### Requirement: Late startup uses immediate bell

When a pending countdown request's scheduled end time is already in the past at consumption time, MalDaze SHALL NOT start a retroactive countdown and SHALL present the center bell immediately using the contract `title`.

#### Scenario: Missed countdown while desk pet was closed
- **WHEN** MalDaze consumes a countdown request after `requestedAt + minutes` has passed
- **THEN** MalDaze shows the center bell with the contract `title`
- **AND** does not start a shortened or full countdown

### Requirement: New countdown replaces in-progress countdown

When MalDaze consumes a new countdown request while any countdown is already running, MalDaze SHALL cancel the in-progress countdown and start the new countdown from the contract.

#### Scenario: Override running countdown
- **WHEN** a countdown is already running
- **AND** MalDaze consumes a new valid countdown request
- **THEN** the previous countdown UI stops without an end bell
- **AND** the new countdown starts with the new contract minutes and title

### Requirement: Countdown intervention execution

When `kind` is `countdown`, MalDaze SHALL start a visible countdown using the contract `minutes` value and SHALL present a center bell with `title` when the countdown completes. The contract `minutes` SHALL take precedence over the user-configured default independent countdown duration.

#### Scenario: Hermes countdown uses contract minutes
- **WHEN** MalDaze consumes `kind: "countdown"` with `minutes: 30`
- **THEN** the countdown runs for thirty minutes
- **AND** the end bell message uses the contract `title`

#### Scenario: User default countdown unchanged
- **WHEN** the user starts the local independent countdown via control panel or global shortcut
- **THEN** MalDaze uses the existing user-configured default duration
- **AND** Hermes contract execution is not required

### Requirement: Immediate bell intervention

When `kind` is `bell`, MalDaze SHALL present the existing center bell reminder immediately with the contract `title` and without starting a countdown.

#### Scenario: Immediate bell
- **WHEN** MalDaze consumes `kind: "bell"` with `title: "关火"`
- **THEN** MalDaze shows the center bell overlay
- **AND** the user dismisses it with the existing click-to-dismiss behavior

### Requirement: Cancel intervention

When `kind` is `cancel`, MalDaze SHALL cancel an in-progress Hermes-initiated countdown if one is active. Cancel SHALL NOT stop an unrelated user-started local countdown unless explicitly unified in implementation.

#### Scenario: Cancel active Hermes countdown
- **WHEN** MalDaze consumes `kind: "cancel"` while a Hermes-initiated countdown is running
- **THEN** MalDaze stops that countdown and dismisses its countdown UI
- **AND** no end bell is shown for the cancelled countdown

### Requirement: Fail-loud invalid contract

MalDaze SHALL NOT silently ignore malformed intervention contracts. Invalid payloads SHALL produce diagnosable failure without partial execution.

#### Scenario: Invalid kind
- **WHEN** the pending file contains an unsupported `kind`
- **THEN** MalDaze does not start countdown or bell
- **AND** MalDaze records a failure suitable for debugging

