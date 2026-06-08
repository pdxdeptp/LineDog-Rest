## ADDED Requirements

### Requirement: Rollover syncs Feishu calendar projection

When `schedule.py rollover` moves incomplete tasks to a new `scheduled_date`, Hermes SHALL patch associated Feishu calendar events to the same date when calendar projection is enabled and the task has `feishu_event_id`. JSON rollover SHALL succeed even if calendar patch fails.

#### Scenario: Rolled task updates calendar date
- **WHEN** rollover changes a task's `scheduled_date` from yesterday to today
- **AND** the task has `feishu_event_id` and `feishu_enabled` is true
- **THEN** Hermes patches the Feishu event to the new all-day date
- **AND** `projects.json` retains the updated `scheduled_date`

#### Scenario: Calendar patch failure does not block rollover
- **WHEN** rollover updates JSON successfully but calendar patch fails
- **THEN** Hermes still persists the rolled task dates in `projects.json`
- **AND** reports calendar errors in the rollover command output
