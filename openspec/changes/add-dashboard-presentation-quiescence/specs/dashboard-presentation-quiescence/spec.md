## ADDED Requirements

### Requirement: Dashboard presentation phase is the authority for background work

MalDaze SHALL maintain a single `DashboardPresentationPhase` (`absent`, `hidden`, `visible`) owned by the Dashboard window controller. The phase SHALL transition to `visible` only when the Dashboard window is shown and to `hidden` when the Dashboard window is hidden with `orderOut` while retaining its hosting controller. SwiftUI view `onAppear` and `onDisappear` callbacks SHALL NOT be the sole authority for whether Dashboard-scoped periodic work may run.

#### Scenario: Hide dashboard quiesces periodic consumers

- **WHEN** the user hides the desk pet Dashboard window
- **THEN** MalDaze sets presentation phase to `hidden`
- **AND** MalDaze pauses every registered Dashboard quiescent consumer
- **AND** no registered consumer keeps a repeating timer or periodic `@Published` refresh for Dashboard UI

#### Scenario: Show dashboard does not eagerly restart all watchers

- **WHEN** the user shows the desk pet Dashboard window after it was hidden
- **THEN** MalDaze sets presentation phase to `visible`
- **AND** MalDaze does not automatically start file watchers or live ticks that require panel `onAppear`
- **AND** visible panels may start watchers on their normal appear path

#### Scenario: New periodic consumer must register

- **WHEN** a new Dashboard-scoped feature introduces repeating timers, live refresh, or file watchers tied to Dashboard visibility
- **THEN** the feature registers with the Dashboard quiescence coordinator
- **AND** the feature pauses when phase is `hidden`

### Requirement: Dashboard hide notifies close lifecycle

MalDaze SHALL post a `deskPetDashboardDidClose` notification when the Dashboard window transitions to hidden, symmetric to the existing open notification.

#### Scenario: Close notification on orderOut

- **WHEN** `hideDashboardWindow` completes
- **THEN** MalDaze posts `deskPetDashboardDidClose`
- **AND** quiescence pause has already run
