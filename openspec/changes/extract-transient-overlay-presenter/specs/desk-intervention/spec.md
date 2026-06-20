## MODIFIED Requirements

### Requirement: Late startup uses immediate bell

When a pending countdown request's scheduled end time is already in the past at consumption time, MalDaze SHALL NOT start a retroactive countdown and SHALL present the center bell immediately through `MalDazeTransientOverlayPresenter` using the contract `title`.

#### Scenario: Missed countdown while desk pet was closed
- **WHEN** MalDaze consumes a countdown request after `requestedAt + minutes` has passed
- **THEN** MalDaze shows the center bell with the contract `title` via the shared transient overlay presenter
- **AND** does not start a shortened or full countdown

### Requirement: Countdown intervention execution

When `kind` is `countdown`, MalDaze SHALL start a visible countdown using the contract `minutes` value and SHALL present a center bell with `title` through `MalDazeTransientOverlayPresenter` when the countdown completes. The contract `minutes` SHALL take precedence over the user-configured default independent countdown duration.

#### Scenario: Hermes countdown uses contract minutes
- **WHEN** MalDaze consumes `kind: "countdown"` with `minutes: 30`
- **THEN** the countdown runs for thirty minutes
- **AND** the end bell message uses the contract `title` presented via the shared transient overlay presenter

#### Scenario: User default countdown unchanged
- **WHEN** the user starts the local independent countdown via control panel or global shortcut
- **THEN** MalDaze uses the existing user-configured default duration
- **AND** Hermes contract execution is not required

### Requirement: Immediate bell intervention

When `kind` is `bell`, MalDaze SHALL present the center bell reminder immediately through `MalDazeTransientOverlayPresenter` with the contract `title` and without starting a countdown.

#### Scenario: Immediate bell
- **WHEN** MalDaze consumes `kind: "bell"` with `title: "关火"`
- **THEN** MalDaze shows the center bell overlay via the shared transient overlay presenter
- **AND** the user dismisses it with the existing click-to-dismiss behavior
