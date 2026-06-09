## MODIFIED Requirements

### Requirement: Today query for desk panel and briefing

Hermes `schedule.py today` SHALL return pending tasks for the requested date plus summary buckets and progress counts sufficient for the MalDaze today tab and morning briefing.

#### Scenario: Today includes completion progress
- **WHEN** `schedule.py today` runs for a date
- **THEN** the JSON includes `progress.study` and `progress.review` objects each with `done` and `total` counts
- **AND** `total` counts all non-failed tasks scheduled that date regardless of completion status
- **AND** `done` counts those with `status: completed`
