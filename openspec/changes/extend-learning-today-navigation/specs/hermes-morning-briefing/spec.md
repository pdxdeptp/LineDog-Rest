## MODIFIED Requirements

### Requirement: Learning section in morning briefing

The morning briefing SHALL include a section summarizing pending learning tasks scheduled for today from `projects.json` via the learning assistant today query.

#### Scenario: Pending index matches desk panel
- **WHEN** `morning-briefing.py` lists today's learning pending tasks
- **THEN** each listed task uses the same `index` values as `schedule.py today` `pending[]` on that date
- **AND** users can complete by index in Feishu using the same numbers shown in the MalDaze today tab
