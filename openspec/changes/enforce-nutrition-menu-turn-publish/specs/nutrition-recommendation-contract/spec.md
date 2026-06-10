## ADDED Requirements

### Requirement: Hermes nutrition source kind naming

New nutrition recommendation snapshots written by Hermes agent Menu Turns SHALL use `source.kind: hermes_nutrition`.

Nutrition-domain code, tests, and skill examples MUST NOT use `feishu_nutrition` as the default or canonical `source.kind`. Feishu MAY be mentioned only as an ingress example, not as the recommendation owner identifier.

#### Scenario: Menu Turn publish uses hermes_nutrition

- **WHEN** Hermes publishes an available recommendation after a Menu Turn
- **THEN** `recommendation.json.source.kind` is `hermes_nutrition`

#### Scenario: Legacy feishu_nutrition snapshot remains readable

- **WHEN** an existing `recommendation.json` on disk still has `source.kind: feishu_nutrition`
- **THEN** MalDaze fresh/stale gating behavior is unchanged
- **AND** the next Hermes publish overwrites with `hermes_nutrition`

### Requirement: Menu Turn recommendation write obligation

When Hermes provides user-visible advice about what to eat next from today's remaining quota in an agent conversation, Hermes SHALL write the same advice to `~/.hermes/data/nutrition/recommendation.json` before the turn is complete.

This obligation applies to agent conversations across ingress channels. Morning Briefing MAY continue using `source.kind: morning_briefing` via its scripted pipeline.

#### Scenario: Agent menu advice matches snapshot

- **WHEN** Hermes tells the user specific next-step food items for today
- **THEN** `recommendation.json` contains those items in `suggestions`
- **AND** `summary` reflects the same user-visible recommendation framing

#### Scenario: Facts-only update does not fake freshness

- **WHEN** Hermes only records or undoes food without Menu Turn advice
- **THEN** Hermes does not write a fresh available recommendation merely to clear stale state

## MODIFIED Requirements

### Requirement: Recommendation snapshot file ownership

Hermes SHALL use `~/.hermes/data/nutrition/recommendation.json` as the only file contract for user-visible nutrition recommendations consumed by MalDaze.

Hermes SHALL write this file only after Hermes has authored or approved a user-visible nutrition recommendation. MalDaze SHALL read this file as a display contract and MUST NOT write it, mutate it, or synthesize a replacement recommendation when it is missing or stale.

#### Scenario: Hermes writes recommendation snapshot

- **WHEN** Hermes gives the user a nutrition recommendation in Morning Briefing or a Hermes agent nutrition Menu Turn
- **THEN** Hermes writes the same recommendation to `~/.hermes/data/nutrition/recommendation.json`
- **AND** the write is atomic and schema-validated

#### Scenario: MalDaze reads recommendation snapshot

- **WHEN** MalDaze renders the nutrition recommendation area
- **THEN** MalDaze reads `~/.hermes/data/nutrition/recommendation.json`
- **AND** MalDaze MUST NOT write or repair the file directly

#### Scenario: Missing recommendation file

- **WHEN** `recommendation.json` does not exist
- **THEN** MalDaze shows a missing/waiting state for recommendations
- **AND** MalDaze MUST NOT call `plan_engine.py`, `recommend.py refresh-panel`, or any local fallback to generate recommendations
