## MODIFIED Requirements

### Requirement: Today query for desk panel and briefing

Hermes `schedule.py today` SHALL return pending tasks for the requested date plus summary buckets, progress counts, optional per-task `source_url`, and a read-only `tomorrow_preview` for the next calendar day.

#### Scenario: Pending includes source URL
- **WHEN** a pending task belongs to a project with `source_url` set
- **THEN** the corresponding `pending[]` entry includes `source_url`
- **AND** omits or nulls the field when the project has no URL

#### Scenario: Tomorrow preview embedded in today
- **WHEN** `schedule.py today` runs
- **THEN** the JSON includes `tomorrow_preview` for the next calendar date with `pending_count`, `study_minutes`, `study_budget`, and up to five preview tasks with `index`, `task_id`, `title`, `project_name`, and `duration_minutes`
- **AND** marks `is_rest_day` when tomorrow is a rest day per profile
