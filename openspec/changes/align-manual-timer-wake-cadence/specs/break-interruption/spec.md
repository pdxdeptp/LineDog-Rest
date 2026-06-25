## MODIFIED Requirements

### Requirement: Manual timer countdown emits at whole-second granularity

When the manual timer engine is running, MalDaze SHALL emit UI-facing countdown state at most once per displayed whole second. The engine SHALL NOT use a sub-second repeating timer when no sub-second UI update is consumed.

#### Scenario: Manual work countdown without sub-second polling

- **WHEN** manual timer is in a work or rest phase with a running countdown
- **THEN** MalDaze updates emitted remaining time at most once per whole second
- **AND** MalDaze does not schedule a repeating timer faster than 1 Hz solely to drive countdown display

#### Scenario: Phase transitions remain immediate

- **WHEN** the manual timer starts or transitions between work and rest
- **THEN** MalDaze emits the new phase state without waiting for the next whole-second tick boundary beyond normal scheduling delay
