## ADDED Requirements

### Requirement: Morning briefing nutrition facts refresh

The Hermes Morning Briefing script SHALL refresh nutrition facts by running the standalone day classification program and the facts panel refresh path.

#### Scenario: Briefing refreshes nutrition facts
- **WHEN** `morning-briefing.py` runs
- **THEN** it runs `day_classification.py`
- **AND** it refreshes `daily_log.json.panel`
- **AND** the briefing prints current day label and remaining macros derived from `daily_log.json`

#### Scenario: Briefing does not use recommend auto
- **WHEN** `morning-briefing.py` runs
- **THEN** it does not run `recommend.py auto`

### Requirement: Morning briefing always publishes nutrition recommendations

Every successful Morning Briefing run SHALL complete the nutrition pipeline: facts refresh, `plan_engine` candidate planning, and a fresh `recommendation.json` write through `morning_briefing_nutrition.py`.

The briefing MUST NOT stop at facts-only output. A facts-only rerun is not a valid completed Morning Briefing delivery.

#### Scenario: Scheduled or manual briefing writes recommendation snapshot
- **WHEN** `morning-briefing.py` runs to completion
- **THEN** it invokes `morning_briefing_nutrition.py`
- **AND** it writes a fresh `recommendation.json` snapshot with `source.kind: "morning_briefing"`
- **AND** `basedOn.dailyLogPanelUpdatedAt` matches the refreshed `daily_log.panel.updatedAt`
- **AND** the briefing output includes user-visible food lines from the authored snapshot

#### Scenario: Briefing replaces stale recommendation snapshot
- **WHEN** `morning-briefing.py` runs while an older `recommendation.json` exists
- **THEN** the older snapshot is replaced by the new morning-briefing-authored snapshot for the refreshed facts

#### Scenario: Planner failure writes explicit unavailable state
- **WHEN** `morning-briefing.py` runs but `plan_engine` or snapshot validation fails
- **THEN** Hermes writes `state: "unavailable"` through `recommendation_store.py`
- **AND** the unavailable `summary` explains the planner/validation failure
- **AND** no legacy no-agent placeholder language is used

### Requirement: Morning briefing planner boundary

`morning-briefing.py` SHALL NOT embed planner logic directly. Planner execution and recommendation snapshot assembly MUST live in `~/.hermes/data/nutrition/morning_briefing_nutrition.py`.

#### Scenario: Briefing delegates planner ownership
- **WHEN** the Morning Briefing script source is inspected
- **THEN** it contains no `get_diet_plan` function
- **AND** it delegates nutrition recommendation publishing to `morning_briefing_nutrition.py`
- **AND** `morning_briefing_nutrition.py` is the only morning-briefing production entrypoint that invokes `plan_engine.py`
