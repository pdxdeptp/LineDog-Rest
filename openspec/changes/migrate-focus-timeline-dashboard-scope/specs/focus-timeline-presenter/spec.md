## ADDED Requirements

### Requirement: Focus timeline lifecycle evaluation

MalDaze SHALL document whether `FocusTimelinePresenter` remains on `AppViewModel` with quiescence discipline or migrates to Dashboard host lifecycle, including trade-offs for state preservation on hide and reopen latency.

#### Scenario: Decision record before migration

- **WHEN** the team considers migrating presenter ownership to the Dashboard host
- **THEN** a design decision records measured energy/ complexity impact after M1 and M2
- **AND** migration does not proceed without explicit approval
