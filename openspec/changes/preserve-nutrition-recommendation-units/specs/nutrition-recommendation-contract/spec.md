## ADDED Requirements

### Requirement: Preserve authored recommendation item quantity labels

MalDaze SHALL display each nutrition recommendation item's `displayName` as the authoritative user-visible food-and-quantity label, including any serving units, parenthetical grams, punctuation, or spacing authored by Hermes. MalDaze MUST continue to use `name` and `grams` only as logging inputs for `recommend.py log <name> <grams>`.

#### Scenario: Serving unit label remains visible

- **WHEN** a fresh `recommendation.json` contains a loggable item with `displayName: "香蕉 1 根 (120g)"`, `name: "香蕉"`, and `grams: 120`
- **THEN** MalDaze displays `香蕉 1 根 (120g)` in the "现在可以吃" row
- **AND** MalDaze does not replace that row with a grams-only quantity such as `120g`

#### Scenario: Logging still uses grams

- **WHEN** the user clicks or digit-key logs the displayed `香蕉 1 根 (120g)` item
- **THEN** MalDaze calls `recommend.py log 香蕉 120`
- **AND** MalDaze does not pass serving-unit text to the logging command
