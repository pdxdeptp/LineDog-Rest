## ADDED Requirements

### Requirement: Morning briefing writes nutrition recommendation snapshot

When the Hermes morning briefing includes a user-visible nutrition recommendation, Hermes SHALL write the same recommendation to `~/.hermes/data/nutrition/recommendation.json` before or during briefing delivery.

The morning briefing nutrition recommendation MUST be authored through the Hermes recommendation path. Raw `plan_engine.py` output MAY be used as candidate context, but MUST NOT be written as a fresh recommendation snapshot unless Hermes has authored or approved the final user-visible recommendation.

#### Scenario: Briefing recommendation is shared with MalDaze

- **WHEN** the morning briefing sends a nutrition recommendation to the user
- **THEN** `recommendation.json` contains the same recommendation summary and structured suggestion items
- **AND** `source.kind` identifies the source as `morning_briefing`
- **AND** `basedOn` references the daily nutrition state used for the briefing

#### Scenario: Programmatic candidate is not published as fresh recommendation

- **WHEN** `morning-briefing.py` runs a deterministic nutrition planner to produce candidate lines
- **THEN** Hermes does not write those candidate lines as an available fresh `recommendation.json` snapshot until the Hermes recommendation path authors or approves them

#### Scenario: Briefing cannot author nutrition recommendation

- **WHEN** the morning briefing cannot produce a reliable Hermes-authored nutrition recommendation
- **THEN** Hermes leaves the existing recommendation stale or writes an unavailable recommendation snapshot
- **AND** an unavailable snapshot uses `summary` for the user-visible reason, has no separate `reason` field, and writes `suggestions: []`
- **AND** MalDaze does not receive a fresh planner-only recommendation
