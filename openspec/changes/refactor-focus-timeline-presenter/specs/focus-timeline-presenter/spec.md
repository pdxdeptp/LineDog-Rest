## ADDED Requirements

### Requirement: Focus timeline uses cached day skeleton plus live overlay

MalDaze SHALL build the learning-desk focus timeline from a **cached day skeleton** plus an optional **live overlay** for the current manual work phase. The skeleton SHALL be rebuilt only when finalized focus sessions for the timeline day change (append, delete, edit) or the timeline day changes. The live overlay SHALL update at most once per displayed second while the consumer is visible and manual work is active.

#### Scenario: Finalize session rebuilds skeleton only

- **WHEN** a manual work phase finalizes as `completed` or `stoppedEarly`
- **THEN** MalDaze rebuilds the focus day skeleton from `focus-sessions.json` for that calendar day
- **AND** MalDaze does not rebuild the skeleton on each timer countdown tick

#### Scenario: Live overlay updates without full grid rebuild

- **WHEN** manual work is active, the learning panel today header is visible, and one displayed second elapses
- **THEN** MalDaze updates only the in-progress live overlay (fill fraction and popover countdown fields)
- **AND** MalDaze does not re-run full day grid layout for finalized sessions on that tick

#### Scenario: Hidden consumer stops live overlay updates

- **WHEN** the learning desk panel is not visible or the today tab header is not shown
- **THEN** MalDaze stops periodic live overlay refresh
- **AND** MalDaze may retain the last skeleton without in-progress overlay

### Requirement: Focus timeline presenter is the sole layout authority for the grid

The learning desk panel focus timeline SHALL read display data from `FocusTimelinePresenter` (or equivalent module). SwiftUI views SHALL NOT invoke `FocusDayTimelineCellGridModel.make()` directly inside `body` on every render.

#### Scenario: Body does not synchronously layout full grid

- **WHEN** SwiftUI evaluates `LearningDeskPanelView` body during unrelated `AppViewModel` changes such as status line countdown text
- **THEN** MalDaze does not synchronously compute a full new day grid model unless skeleton inputs changed

### Requirement: Active manual work phase maintains wall-clock invariant

While manual work is active and not in rest phase, the engine and coordinator projection SHALL maintain `phaseStart ≤ now ≤ phaseEnd` (local wall clock).

#### Scenario: Skip rest early starts work at now

- **WHEN** the user ends rest early and enters the next work phase
- **THEN** the new work phase `startedAt` equals the wall-clock instant of the transition
- **AND** `startedAt` is not scheduled in the future at the previous rest phase end

#### Scenario: Grid build never traps on interval construction

- **WHEN** the presenter merges skeleton and live overlay for display
- **THEN** MalDaze constructs display intervals only from pairs where `start ≤ end`
- **AND** an invalid pair SHALL omit in-progress fill rather than crashing the app in production

### Requirement: Focus timeline observation is decoupled from desk status line

Updates to the desk-pet **status line countdown string alone** SHALL NOT invalidate the focus timeline presenter skeleton or trigger full grid layout.

#### Scenario: Status line tick without session change

- **WHEN** manual work countdown text changes each second but no focus session is finalized and phase boundaries are unchanged
- **THEN** the focus timeline presenter may update live overlay fields
- **AND** MalDaze does not publish a full new skeleton model solely because the status line string changed
