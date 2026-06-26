## ADDED Requirements

### Requirement: Learning projects file watcher follows dashboard quiescence

MalDaze SHALL start and stop the Hermes learning projects file watcher exclusively through the Dashboard quiescence coordinator registered pause and resume handlers. The learning desk panel SHALL NOT subscribe to `deskPetDashboardDidClose` or use SwiftUI `onAppear` / `onDisappear` as the authority for starting or stopping the file watcher.

#### Scenario: Hide dashboard stops learning file watcher

- **WHEN** the Dashboard presentation phase becomes `hidden`
- **THEN** MalDaze stops the learning projects file watcher if it was started
- **AND** the stop is performed by the coordinator pause handler registered at app composition root

#### Scenario: Show dashboard resumes learning file watcher

- **WHEN** the Dashboard presentation phase becomes `visible` after being `hidden`
- **THEN** MalDaze restarts the learning projects file watcher without requiring SwiftUI `onAppear`
- **AND** MalDaze performs a non-blocking catch-up reload of the learning panel data appropriate to the current tab

#### Scenario: Hermes projects update while dashboard visible

- **WHEN** Hermes updates the watched learning projects file and the Dashboard presentation phase is `visible`
- **THEN** MalDaze refreshes the learning panel from disk within the existing debounce window
