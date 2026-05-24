## ADDED Requirements

### Requirement: Dashboard reminder plan notes
The Dashboard left reminder plan sidebar SHALL display human-facing reminder notes when they are present.

#### Scenario: Reminder with notes
- **WHEN** the Dashboard left "计划" sidebar renders an incomplete reminder whose notes contain user-facing text
- **THEN** the reminder row displays the reminder title
- **AND** the row displays the user-facing notes as secondary detail text beneath the title
- **AND** the row still displays due-time and action controls

#### Scenario: Routine marker is hidden from notes
- **WHEN** a reminder note contains a standalone `#日常` marker line and additional user-facing text
- **THEN** the row displays the routine badge
- **AND** the row displays the additional user-facing text
- **AND** the row does not display the standalone `#日常` marker as note detail text

#### Scenario: Reminder without notes
- **WHEN** the Dashboard left "计划" sidebar renders a reminder without user-facing notes
- **THEN** the reminder row displays the title and due-time information without an empty detail line
