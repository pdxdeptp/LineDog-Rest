## MODIFIED Requirements

### Requirement: Morning briefing always publishes nutrition recommendations

Every successful Morning Briefing run SHALL complete the nutrition pipeline: facts refresh, `plan_engine` candidate planning, and a fresh `recommendation.json` write through `morning_briefing_nutrition.py`.

The briefing MUST NOT stop at facts-only output. A facts-only rerun is not a valid completed Morning Briefing delivery.

Morning Briefing scripted publish (`source.kind: morning_briefing`) is separate from Hermes agent Menu Turn publish (`source.kind: hermes_nutrition`). Morning Briefing behavior MUST NOT depend on agent Menu Turn classification.

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

#### Scenario: Agent Menu Turn does not replace morning briefing script

- **WHEN** a user later runs a Hermes agent Menu Turn the same day
- **THEN** agent publish may overwrite `recommendation.json` with `hermes_nutrition`
- **AND** the next scheduled Morning Briefing run still follows the scripted `morning_briefing` pipeline
