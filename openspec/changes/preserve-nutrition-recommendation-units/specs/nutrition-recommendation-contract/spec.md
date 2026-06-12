## ADDED Requirements

### Requirement: Preserve authored recommendation item quantity labels and calories

MalDaze SHALL display each nutrition recommendation item's `displayName` as the authoritative user-visible food-and-quantity label, including any serving units, parenthetical grams, punctuation, or spacing authored by Hermes. When a recommendation item includes numeric `kcal`, MalDaze SHALL display that per-item calorie value beside the item. MalDaze MUST continue to use `name` and `grams` only as logging inputs for `recommend.py log <name> <grams>`, and MUST NOT derive item calories locally from `foods.json` or other nutrition databases.

#### Scenario: Serving unit label remains visible

- **WHEN** a fresh `recommendation.json` contains a loggable item with `displayName: "香蕉 1 根 (120g)"`, `name: "香蕉"`, `grams: 120`, and `kcal: 107`
- **THEN** MalDaze displays `香蕉 1 根 (120g)` in the "现在可以吃" row
- **AND** MalDaze does not replace that row with a grams-only quantity such as `120g`
- **AND** MalDaze displays `107 kcal` for that item

#### Scenario: Logging still uses grams

- **WHEN** the user clicks or digit-key logs the displayed `香蕉 1 根 (120g)` item
- **THEN** MalDaze calls `recommend.py log 香蕉 120`
- **AND** MalDaze does not pass serving-unit text to the logging command

#### Scenario: Calories absent from snapshot

- **WHEN** a fresh `recommendation.json` item does not include `kcal`
- **THEN** MalDaze displays the authored `displayName`
- **AND** MalDaze does not calculate a replacement calorie value from local food data
