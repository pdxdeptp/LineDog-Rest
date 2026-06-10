## ADDED Requirements

### Requirement: Deterministic scripts do not own recommendation snapshots

Morning Briefing SHALL always complete nutrition recommendation publishing through `morning_briefing_nutrition.py`; a facts-only briefing run is invalid.

Other deterministic Hermes scripts SHALL NOT write `~/.hermes/data/nutrition/recommendation.json` merely because no nutrition authoring step is running.

`recommendation.json` SHALL be written by Hermes nutrition authoring flows that either provide a user-visible food recommendation or explicitly author a user-visible unavailable recommendation state.

#### Scenario: Facts refresh leaves recommendation untouched
- **WHEN** a deterministic script refreshes nutrition facts by running day classification or `recommend.py refresh-panel`
- **THEN** it does not create, replace, or clear `recommendation.json`

#### Scenario: No placeholder recommendation state
- **WHEN** Morning Briefing runs without a Hermes nutrition authoring step
- **THEN** `recommendation.json` is left missing, stale, or unchanged
- **AND** it is not replaced with a script-authored unavailable placeholder

### Requirement: Unavailable recommendation is Hermes-authored

`recommendation.json state: "unavailable"` SHALL represent an explicit Hermes-authored user-visible decision that reliable food advice cannot be given for the current context. It SHALL NOT represent a deterministic script's inability to call an AI model.

Unavailable snapshots SHALL still use `summary` for the user-visible explanation and `suggestions: []`.

#### Scenario: Authored unavailable state
- **WHEN** Hermes nutrition authoring decides not to recommend food because the context is unreliable
- **THEN** Hermes MAY write `recommendation.json` with `state: "unavailable"`
- **AND** `summary` explains the user-visible reason
- **AND** `suggestions` is an empty array

#### Scenario: Script absence is not unavailable
- **WHEN** only a deterministic facts-refresh script has run
- **THEN** it MUST NOT write `state: "unavailable"` to stand in for an absent Hermes author

### Requirement: Reply and snapshot stay consistent

Whenever Hermes replies to the user with next-step food advice, Hermes SHALL write the same advice to `recommendation.json` before or during reply delivery.

The snapshot SHALL reference the `daily_log.json.panel.updatedAt` value that was current when Hermes authored the advice.

#### Scenario: User-visible recommendation is written
- **WHEN** Hermes replies with a plan for what the user should eat next
- **THEN** `recommendation.json.state` is `available`
- **AND** `recommendation.json.summary` and `suggestions` represent the same advice as the reply
- **AND** `basedOn.dailyLogPanelUpdatedAt` matches the facts used for authoring

#### Scenario: Advice after food log uses post-log facts
- **WHEN** Hermes records food and then replies with what to eat next
- **THEN** `recommendation.json.basedOn.dailyLogPanelUpdatedAt` references the post-log `daily_log.panel.updatedAt`
