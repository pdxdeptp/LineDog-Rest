## MODIFIED Requirements

### Requirement: Dashboard presentation phase is the authority for background work

MalDaze SHALL maintain a single `DashboardPresentationPhase` (`absent`, `hidden`, `visible`) owned by the Dashboard window controller. The phase SHALL transition to `visible` only when the Dashboard window is shown and to `hidden` when the Dashboard window is hidden with `orderOut` while retaining its hosting controller. SwiftUI view `onAppear` and `onDisappear` callbacks SHALL NOT be the sole authority for whether Dashboard-scoped periodic work may run.

MalDaze SHALL register Dashboard quiescent consumers with paired pause and resume handlers on `DashboardQuiescenceCoordinator`. When presentation phase transitions from `hidden` to `visible`, MalDaze SHALL invoke every registered resume handler. When presentation phase transitions from `visible` to `hidden`, MalDaze SHALL invoke every registered pause handler.

#### Scenario: Hide dashboard quiesces periodic consumers

- **WHEN** the user hides the desk pet Dashboard window
- **THEN** MalDaze sets presentation phase to `hidden`
- **AND** MalDaze pauses every registered Dashboard quiescent consumer
- **AND** no registered consumer keeps a repeating timer or periodic `@Published` refresh for Dashboard UI
- **AND** no registered Hermes file watcher remains active

#### Scenario: Show dashboard resumes registered file watchers

- **WHEN** the user shows the desk pet Dashboard window after it was hidden with `orderOut`
- **THEN** MalDaze sets presentation phase to `visible`
- **AND** MalDaze invokes every registered resume handler
- **AND** registered Hermes file watcher consumers restart listening without requiring SwiftUI `onAppear`
- **AND** registered file watcher consumers perform a non-blocking catch-up read of their Hermes contract files

#### Scenario: Show dashboard does not blindly restart tab-gated live ticks

- **WHEN** the user shows the desk pet Dashboard window after it was hidden
- **THEN** MalDaze does not automatically set the focus timeline live consumer visible unless the Today timeline row is visible per its existing tab-gated appear path
- **AND** MalDaze still resumes registered file watcher consumers per the show scenario above

#### Scenario: New periodic consumer must register

- **WHEN** a new Dashboard-scoped feature introduces repeating timers, live refresh, or file watchers tied to Dashboard visibility
- **THEN** the feature registers paired pause and resume handlers with the Dashboard quiescence coordinator
- **AND** the feature pauses when phase is `hidden`
- **AND** the feature resumes when phase becomes `visible` from `hidden`

### Requirement: Dashboard hide notifies close lifecycle

MalDaze SHALL post a `deskPetDashboardDidClose` notification when the Dashboard window transitions to hidden, symmetric to the existing open notification.

#### Scenario: Close notification on orderOut

- **WHEN** `hideDashboardWindow` completes
- **THEN** MalDaze posts `deskPetDashboardDidClose`
- **AND** quiescence pause has already run

## REMOVED Requirements

### Requirement: Show dashboard does not eagerly restart all watchers

**Reason**: Conflicts with `orderOut` state preservation — SwiftUI `onAppear` does not fire again when the hosting controller is retained, leaving Hermes file watchers permanently stopped after the first hide.

**Migration**: Show transitions invoke coordinator `resumeAll()` for registered file watcher consumers; tab-gated live ticks remain governed by their existing visible hints.
