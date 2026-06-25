## MODIFIED Requirements

### Requirement: Focus timeline uses cached day skeleton plus live overlay

MalDaze SHALL build the learning-desk focus timeline from a **cached day skeleton** plus an optional **live overlay** for the current manual work phase. The skeleton SHALL be rebuilt only when finalized focus sessions for the timeline day change (append, delete, edit) or the timeline day changes. The live overlay SHALL update at most once per displayed second while the consumer is visible **and manual work is active**. While the consumer is visible but manual work is **not** active (for example autoWatching), MalDaze SHALL NOT run a periodic live refresh timer and SHALL NOT assign `displayModel` on a timer cadence.

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

#### Scenario: Auto-watching visible consumer does not periodic publish

- **WHEN** the focus timeline consumer is visible
- **AND** timer mode is autoWatching (no active manual work phase)
- **THEN** MalDaze does not run a repeating or one-shot live refresh timer for the focus timeline
- **AND** MalDaze does not assign `displayModel` once per second solely because wall clock advances
- **AND** MalDaze may update the skeleton when finalized session inputs change

#### Scenario: Manual work ends clears overlay once

- **WHEN** manual work was active with a visible in-progress overlay
- **AND** the work phase ends or the user is no longer in manual work
- **THEN** MalDaze stops the live refresh timer
- **AND** MalDaze clears the in-progress overlay with at most one `displayModel` publish
- **AND** MalDaze does not continue periodic publishes while idle-visible
