## MODIFIED Requirements

### Requirement: Panel does not depend on external calendars

MalDaze learning desk panel SHALL treat Hermes `projects.json` (via CLI) as the only schedule source and SHALL NOT display or require Feishu calendar sync status for learning operations.

#### Scenario: Mutation success without calendar fields
- **WHEN** the user completes, moves, or edits deadline from the panel
- **AND** Hermes returns success without `calendar_errors`
- **THEN** the panel shows only learning-specific notices (repack count, overflow, etc.)
- **AND** does not mention calendar-sync remediation
