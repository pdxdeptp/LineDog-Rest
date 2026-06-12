## Why

The Dashboard nutrition panel's "现在可以吃" rows currently make loggable food quantities look grams-only, while Hermes-authored advice can contain serving units such as 根 or 勺 in the user-visible item text. It also loses per-item calories when Hermes syncs recommendation items as structured data. Users should see the same authored quantity wording and item calories in MalDaze that Hermes uses in conversation, without changing the logging contract.

## What Changes

- Treat `recommendation.json` item `displayName` as the authoritative user-visible food-and-quantity label, including any serving units Hermes authored.
- Decode and display optional per-item `kcal` from `recommendation.json` when Hermes provides it.
- Keep `grams` as the machine-readable logging amount for `recommend.py log <name> <grams>`.
- Adjust MalDaze recommendation rows so grams-only UI affordances do not replace or visually compete with the authored `displayName`, while calories remain visible when present.
- Add focused regression coverage for a recommendation item like `香蕉 1 根 (120g)` remaining visible with `107 kcal` while logging still uses `120` grams.

## Capabilities

### New Capabilities

- `nutrition-recommendation-contract`: Defines how Hermes-authored nutrition recommendation item labels and optional item calories are displayed and logged by MalDaze.

### Modified Capabilities

None.

## Impact

- Affects `MalDaze/NutritionToday` recommendation decoding, display/model helpers, and focused nutrition tests.
- Does not change `recommendation.json` schema version, Hermes file ownership, `recommend.py log` arguments, persistence keys, or nutrition calculation behavior.
