## ADDED Requirements

### Requirement: Morning briefing nutrition facts refresh

The Hermes Morning Briefing deterministic script SHALL refresh nutrition facts by running the standalone day classification program and the facts panel refresh path.

The deterministic script SHALL NOT perform Hermes nutrition authoring inside `morning-briefing.py`.

#### Scenario: Briefing refreshes nutrition facts
- **WHEN** `morning-briefing.py` runs
- **THEN** it runs `day_classification.py`
- **AND** it refreshes `daily_log.json.panel`
- **AND** the briefing can print current day label and facts derived from `daily_log.json`

#### Scenario: Briefing does not use recommend auto
- **WHEN** `morning-briefing.py` runs
- **THEN** it does not run `recommend.py auto`

### Requirement: Morning briefing does not publish unauthored recommendations

The deterministic Morning Briefing script SHALL NOT create, replace, or clear `recommendation.json`. If no Hermes authoring step runs, the recommendation snapshot remains missing, stale, or unchanged.

#### Scenario: Script-only briefing leaves recommendation file untouched
- **WHEN** `morning-briefing.py` runs in an environment with an existing `recommendation.json`
- **THEN** the file content is unchanged by the deterministic script

#### Scenario: Script-only briefing does not create recommendation file
- **WHEN** `morning-briefing.py` runs in an environment without `recommendation.json`
- **THEN** no `recommendation.json` file is created by the deterministic script

### Requirement: Morning briefing legacy planner code removed

`morning-briefing.py` SHALL NOT contain or call legacy user-visible diet planner code. In particular, it SHALL NOT define `get_diet_plan`, SHALL NOT call `plan_engine.py`, and SHALL NOT pass `--full-day` for Morning Briefing nutrition recommendations.

Planner output MAY still be used by a separate Hermes authoring flow as candidate context, but it MUST NOT live in the deterministic Morning Briefing script.

#### Scenario: No legacy planner helper
- **WHEN** the Morning Briefing script source is inspected
- **THEN** it contains no `get_diet_plan` function
- **AND** it contains no `plan_engine.py` invocation
- **AND** it contains no Morning Briefing `--full-day` planner call

### Requirement: Morning briefing authored recommendations are external to the deterministic script

When a Morning Briefing delivery includes user-visible food advice, Hermes SHALL perform an authoring step outside the deterministic facts-refresh script and write the same advice to `recommendation.json`.

#### Scenario: Rerun morning briefing with food advice
- **WHEN** the user asks Hermes to rerun Morning Briefing
- **AND** Hermes replies with what to eat next
- **THEN** Hermes writes an available `recommendation.json` snapshot with `source.kind: "morning_briefing"`
- **AND** the snapshot uses the refreshed facts from that briefing run

#### Scenario: Rerun morning briefing without food advice
- **WHEN** the user asks Hermes to rerun Morning Briefing
- **AND** Hermes does not author food advice
- **THEN** Hermes does not write a fresh available recommendation snapshot
- **AND** the deterministic script does not write an unavailable placeholder
