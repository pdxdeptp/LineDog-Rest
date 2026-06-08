## ADDED Requirements

### Requirement: Today pending includes auto roll days

When `schedule.py today` builds the `pending` list, each pending row SHALL include `auto_roll_days` when present on the underlying task so clients do not need to merge nested study task payloads.

#### Scenario: Pending row exposes rollover count
- **WHEN** a pending task has `auto_roll_days` greater than zero in `projects.json`
- **THEN** the corresponding `pending[]` entry includes the same `auto_roll_days` value

### Requirement: Week load CLI

Hermes `schedule.py` SHALL provide a `week-load` subcommand that returns per-day scheduled study minutes for a forward date window and flags days exceeding `daily_capacity_minutes` from profile.

#### Scenario: Week load JSON output
- **WHEN** MalDaze or tooling runs `schedule.py week-load --from <date> --days 28`
- **THEN** Hermes prints JSON with one entry per day including `total_minutes`, `budget`, and `over_capacity: true|false`
- **AND** only counts incomplete study and review tasks scheduled on each day
