## ADDED Requirements

### Requirement: Standalone day classification program

Hermes SHALL provide a standalone nutrition day classification program at `~/.hermes/data/nutrition/day_classification.py`.

Production callers SHALL classify the current nutrition day by executing:

```bash
python3 day_classification.py
```

The program SHALL classify the current nutrition date as `training` or `rest` using `profile.json.training_rhythm_days` and `training_log.json` strength records (`is_training: true`) as the single source of truth for prior training days. It SHALL update `daily_log.json.day_type` and SHALL return structured JSON containing at least `day_type`, `label`, `last_trained`, `rhythm_days`, and `days_since`.

#### Scenario: First known day becomes training
- **WHEN** `training_log.json` has no `is_training: true` records
- **AND** `python3 day_classification.py` runs
- **THEN** `daily_log.json.day_type` is `training`
- **AND** the command output contains `"day_type": "training"`

#### Scenario: Rhythm determines rest day
- **WHEN** `profile.json.training_rhythm_days` is `2`
- **AND** the most recent `training_log.json` `is_training: true` record is yesterday
- **AND** `python3 day_classification.py` runs today
- **THEN** `daily_log.json.day_type` is `rest`
- **AND** the command output contains `"day_type": "rest"`

### Requirement: Workout split synchronization

The day classification program SHALL own the automatic workout split side effects that are part of training/rest day classification.

When the classified day is `training`, the program SHALL assign `daily_log.json.workout_split` by alternating from the latest prior strength-training `workout_split` in `training_log.json`, and SHALL ensure today's `is_training: true` training-log record contains the same `workout_split`.

When the classified day is `rest`, the program SHALL remove `daily_log.json.workout_split` and SHALL NOT create a strength-training record for today.

#### Scenario: Training day assigns split
- **WHEN** today is classified as `training`
- **AND** the latest prior strength workout has `workout_split: "chest"`
- **THEN** `daily_log.json.workout_split` is `back_legs`
- **AND** today's `training_log.json` `is_training: true` record has `workout_split: "back_legs"`

#### Scenario: Rest day clears split
- **WHEN** today is classified as `rest`
- **THEN** `daily_log.json` has no `workout_split` field
- **AND** no new `is_training: true` record is created for today

### Requirement: Classification refreshes daily facts safely

The day classification program SHALL update `daily_log.json` using the same atomic/locked daily-log persistence path used by the nutrition facts engine. The resulting `daily_log.json` SHALL include a valid `panel` block with targets, consumed, remaining, day label, and updated timestamp.

The program SHALL NOT write `recommendation.json`.

#### Scenario: Classification updates panel facts
- **WHEN** `python3 day_classification.py` runs successfully
- **THEN** `daily_log.json.panel.schemaVersion` is `1`
- **AND** `daily_log.json.panel.dayLabel` matches the classified day type
- **AND** `daily_log.json.panel.updatedAt` is present

#### Scenario: Classification does not write recommendation
- **WHEN** `python3 day_classification.py` runs
- **THEN** it does not create or replace `recommendation.json`

### Requirement: recommend.py auto compatibility wrapper

`recommend.py auto` SHALL remain available only as a compatibility wrapper during migration. It SHALL delegate day classification to the standalone day classification implementation and SHALL NOT contain independent day classification logic.

New production callers and Hermes skill docs MUST use `python3 day_classification.py` instead of `python3 recommend.py auto`.

#### Scenario: Legacy auto still works
- **WHEN** `python3 recommend.py auto` runs
- **THEN** it returns the same classification payload shape as `python3 day_classification.py`
- **AND** `daily_log.json.day_type` is updated through the standalone classification implementation

#### Scenario: Morning briefing uses standalone classifier
- **WHEN** `morning-briefing.py` refreshes nutrition facts
- **THEN** it invokes `day_classification.py`
- **AND** it does not invoke `recommend.py auto`
