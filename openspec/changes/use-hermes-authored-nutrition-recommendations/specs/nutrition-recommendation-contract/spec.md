## ADDED Requirements

### Requirement: Recommendation snapshot file ownership

Hermes SHALL use `~/.hermes/data/nutrition/recommendation.json` as the only file contract for user-visible nutrition recommendations consumed by MalDaze.

Hermes SHALL write this file only after Hermes has authored or approved a user-visible nutrition recommendation. MalDaze SHALL read this file as a display contract and MUST NOT write it, mutate it, or synthesize a replacement recommendation when it is missing or stale.

#### Scenario: Hermes writes recommendation snapshot

- **WHEN** Hermes gives the user a nutrition recommendation in Morning Briefing or Feishu conversation
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

### Requirement: Recommendation snapshot schema

`recommendation.json` SHALL use `schemaVersion: 1` and contain `date`, `generatedAt`, `source`, `basedOn`, `state`, `summary`, and `suggestions`.

Each suggestion SHALL contain a user-visible `label`, optional `rationale`, `items`, and optional `warnings`. Each item SHALL contain `displayName` and `loggable`. When `loggable` is `true`, the item MUST contain `name` matching a `foods.json` key and numeric positive `grams`.

For `state: "unavailable"`, the first version SHALL NOT add a separate `reason` field. The `recommendation_store.py unavailable --reason` CLI SHALL map the provided reason into `summary`, which MalDaze MAY display as the unavailable-state copy, and `suggestions` MUST be `[]`.

#### Scenario: Valid available recommendation

- **WHEN** Hermes writes an available recommendation
- **THEN** `recommendation.json.state` is `available`
- **AND** `summary` contains the user-visible recommendation summary
- **AND** every `loggable: true` item includes `name` and `grams`

#### Scenario: Valid unavailable recommendation

- **WHEN** Hermes runs `recommendation_store.py unavailable --reason "QA cannot recommend reliably"`
- **THEN** `recommendation.json.state` is `unavailable`
- **AND** `summary` contains `QA cannot recommend reliably` or equivalent user-visible unavailable copy
- **AND** `recommendation.json` has no separate `reason` field
- **AND** `suggestions` is an empty array `[]`

#### Scenario: Text-only recommendation item

- **WHEN** Hermes includes a recommendation item that cannot be logged through `recommend.py log`
- **THEN** the item has `loggable: false`
- **AND** MalDaze displays the item without click or digit-key logging affordance

#### Scenario: Invalid loggable item rejected

- **WHEN** Hermes attempts to write a `loggable: true` item whose `name` is not present in `foods.json`
- **THEN** the recommendation writer rejects the snapshot
- **AND** the existing `recommendation.json` is left unchanged

### Requirement: Recommendation freshness

MalDaze SHALL treat a recommendation snapshot as fresh only when it is based on the currently displayed nutrition facts.

A snapshot is fresh when `recommendation.date` equals `daily_log.date` and `recommendation.basedOn.dailyLogPanelUpdatedAt` equals `daily_log.panel.updatedAt`. If either comparison fails, MalDaze SHALL display the recommendation as stale and MUST NOT present its loggable items as current actions.

#### Scenario: Fresh recommendation

- **WHEN** `recommendation.date` matches `daily_log.date`
- **AND** `recommendation.basedOn.dailyLogPanelUpdatedAt` matches `daily_log.panel.updatedAt`
- **THEN** MalDaze displays the recommendation as current
- **AND** MalDaze enables click and digit-key logging for `loggable: true` items

#### Scenario: Stale recommendation after food log

- **WHEN** the user records food and `daily_log.panel.updatedAt` changes
- **AND** `recommendation.basedOn.dailyLogPanelUpdatedAt` still references the older panel timestamp
- **THEN** MalDaze displays the recommendation as stale
- **AND** MalDaze disables recommendation logging actions until Hermes writes a fresh snapshot

#### Scenario: Recommendation from previous date

- **WHEN** `recommendation.date` differs from `daily_log.date`
- **THEN** MalDaze displays the recommendation as stale or unavailable for today
- **AND** MalDaze does not show it as today's current food plan

### Requirement: No programmatic recommendation fallback

`recommend.py` and `plan_engine.py` SHALL NOT publish user-visible nutrition recommendations directly to MalDaze. They MAY produce facts, status, trials, or candidate plans for Hermes authoring, but a recommendation MUST become user-visible in MalDaze only through `recommendation.json`.

`daily_log.json.panel.suggestions` MUST NOT be used by MalDaze as a recommendation source. In the first version, Hermes SHALL keep `daily_log.panel.suggestions` as an empty array `[]` for backward-compatible schema handling; a future `panel` schema version MAY remove the field.

#### Scenario: refresh-panel updates metrics only

- **WHEN** `recommend.py refresh-panel` runs
- **THEN** `daily_log.panel.targets`, `consumed`, `remaining`, and `updatedAt` may update
- **AND** `recommend.py` does not generate user-visible recommendations for MalDaze
- **AND** `daily_log.panel.suggestions` remains an empty array for compatibility

#### Scenario: plan_engine candidate not displayed directly

- **WHEN** `plan_engine.py` produces a candidate plan
- **THEN** MalDaze does not display that output unless Hermes authors a recommendation snapshot from it

#### Scenario: Existing panel suggestions ignored

- **WHEN** `daily_log.json.panel.suggestions` contains legacy data
- **THEN** MalDaze ignores that field for the user-visible recommendation area
- **AND** MalDaze uses only `recommendation.json` for recommendations

### Requirement: MalDaze recommendation display and logging

MalDaze SHALL display nutrition facts from `daily_log.json` and recommendations from `recommendation.json` as separate sources.

For fresh recommendations, MalDaze SHALL display `summary`, suggestion labels, rationale, warnings, and items. MalDaze SHALL allow clicking or digit-key logging only for fresh `loggable: true` items, and logging MUST call `recommend.py log <name> <grams>` rather than editing JSON.

#### Scenario: Fresh loggable item clicked

- **WHEN** the recommendation is fresh
- **AND** the user clicks a `loggable: true` item with `name` and `grams`
- **THEN** MalDaze calls `recommend.py log <name> <grams>`
- **AND** MalDaze reloads nutrition facts after the command finishes

#### Scenario: Fresh text-only item displayed

- **WHEN** the recommendation is fresh
- **AND** an item has `loggable: false`
- **THEN** MalDaze displays the item text
- **AND** MalDaze does not expose click or digit-key logging for that item

#### Scenario: Stale recommendation actions disabled

- **WHEN** the recommendation is stale
- **THEN** MalDaze may show the old recommendation for context with stale labeling
- **AND** MalDaze disables click and digit-key logging for its items

### Requirement: Hermes conversation updates recommendation snapshot

When a Hermes nutrition conversation records food, undoes food, changes day type, or otherwise updates the nutrition state and then gives the user a next-step food recommendation, Hermes SHALL write a fresh `recommendation.json` snapshot based on the resulting `daily_log` state.

If Hermes updates nutrition facts but cannot provide a recommendation, Hermes SHALL write `state: "unavailable"` or leave the existing snapshot stale; it MUST NOT write a programmatic planner result as a fresh recommendation without Hermes authoring. When Hermes writes unavailable, the unavailable payload MUST use `summary` for the user-visible reason and `suggestions: []`.

#### Scenario: Feishu log with follow-up recommendation

- **WHEN** the user tells Hermes in Feishu that they ate a food
- **AND** Hermes records it through `recommend.py log`
- **AND** Hermes replies with what to eat next
- **THEN** Hermes writes `recommendation.json` with `source.kind` identifying the Feishu nutrition flow
- **AND** `basedOn` references the post-log `daily_log` state

#### Scenario: Feishu log without recommendation

- **WHEN** Hermes records a food update but cannot generate a reliable next-step recommendation
- **THEN** Hermes does not write a fresh available recommendation
- **AND** if Hermes writes unavailable, `summary` carries the display reason and `suggestions` is `[]`
- **AND** MalDaze will show missing, stale, or unavailable recommendation state
