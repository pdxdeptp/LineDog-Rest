## REMOVED Requirements

### Requirement: Dashboard today focus visualization
**Reason**: Focus visualization moves to the learning desk panel today header as a proportional-fill cell grid over 08:00–24:00; the right controls column returns to timer operations only.
**Migration**: Users find today's focus activity in the middle-column learning panel today tab header instead of the right-column session list.

## ADDED Requirements

### Requirement: Right controls column excludes focus session list
The Dashboard right controls column SHALL NOT display a per-session today focus list, summary block, or in-progress text row between the status chip and primary timer actions.

#### Scenario: No focus list in controls column
- **WHEN** the Dashboard panel is visible
- **THEN** the right column does not render `FocusSessionTodaySection` or an equivalent list of today's focus sessions
- **AND** timer mode, start/stop/resume, and other control affordances remain available unchanged

#### Scenario: Focus data still persisted
- **WHEN** manual focus sessions are finalized
- **THEN** MalDaze continues to append sessions to local JSON under the existing focus session persistence rules
- **AND** removal of the right-column list does not disable persistence
