## 1. Regression Coverage

- [ ] 1.1 Add a focused failing test proving a loggable recommendation item with `displayName` such as `香蕉 1 根 (120g)` keeps that authored label while still mapping logging to `grams: 120`.

## 2. Display Implementation

- [ ] 2.1 Update `NutritionToday` recommendation row display so authored `displayName` remains the visible quantity/unit label and grams-only text is only a fallback when the label does not already contain the gram amount.

## 3. Verification

- [ ] 3.1 Run focused nutrition tests and `openspec validate preserve-nutrition-recommendation-units --strict`.
- [ ] 3.2 Provide manual QA steps for confirming the Dashboard "现在可以吃" row with serving units.
