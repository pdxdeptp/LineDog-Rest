## Why

The Dashboard nutrition panel's "现在可以吃" rows currently make loggable food quantities look grams-only, while Hermes-authored advice can contain serving units such as 根 or 勺 in the user-visible item text. Users should see the same authored quantity wording in MalDaze that Hermes uses in conversation, without changing the logging contract.

## What Changes

- Treat `recommendation.json` item `displayName` as the authoritative user-visible food-and-quantity label, including any serving units Hermes authored.
- Keep `grams` as the machine-readable logging amount for `recommend.py log <name> <grams>`.
- Adjust MalDaze recommendation rows so grams-only UI affordances do not replace or visually compete with the authored `displayName`.
- Add focused regression coverage for a recommendation item like `香蕉 1 根 (120g)` remaining visible while logging still uses `120` grams.

## Capabilities

### New Capabilities

- `nutrition-recommendation-contract`: Defines how Hermes-authored nutrition recommendation item labels are displayed and logged by MalDaze.

### Modified Capabilities

None.

## Impact

- Affects `MalDaze/NutritionToday` display/model helpers and focused nutrition tests.
- Does not change `recommendation.json` schema version, Hermes file ownership, `recommend.py log` arguments, persistence keys, or nutrition calculation behavior.
