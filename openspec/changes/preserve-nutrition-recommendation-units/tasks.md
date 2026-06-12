## 1. Regression Coverage

- [x] 1.1 Add a focused failing test proving a loggable recommendation item with `displayName` such as `香蕉 1 根 (120g)` keeps that authored label while still mapping logging to `grams: 120`.
- [x] 1.2 Add a focused failing test proving optional recommendation item `kcal` is decoded, carried into `NutritionLoggableItem`, and shown as item display metadata without affecting logging.

## 2. Display Implementation

- [x] 2.1 Update `NutritionToday` recommendation row display so authored `displayName` remains the visible quantity/unit label and grams-only text is only a fallback when the label does not already contain the gram amount.
- [x] 2.2 Decode optional `kcal` from `recommendation.json` items and pass it through to recommendation row display.
- [x] 2.3 Update canonical Hermes integration docs to state that item `kcal` is Hermes-authored display metadata and MalDaze does not derive it locally.

## 3. Verification

- [x] 3.1 Run focused nutrition tests and `openspec validate preserve-nutrition-recommendation-units --strict`.
- [x] 3.2 Provide manual QA steps for confirming the Dashboard "现在可以吃" row with serving units and kcal.
