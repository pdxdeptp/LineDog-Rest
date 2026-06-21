## MODIFIED Requirements

### Requirement: Timer pause and resume preserve manual focus continuity
Desk pet / control panel timer actions SHALL pause and resume the current manual focus block without treating pause as an abandoned pomodoro.

#### Scenario: Stop timers during manual work keeps segment alive
- **WHEN** the user chooses stop/pause while manual work is active
- **THEN** MalDaze stops engines and shows resume affordance
- **AND** does not append a focus session for the pause alone

#### Scenario: Resume timers restores manual work segment
- **WHEN** the user resumes after pausing manual work
- **THEN** MalDaze continues the same work segment rather than opening a new one
- **AND** focus session projection omits in-progress fill while paused
