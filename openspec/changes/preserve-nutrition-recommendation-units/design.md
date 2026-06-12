## Context

MalDaze reads user-visible nutrition recommendations from Hermes-owned `~/.hermes/data/nutrition/recommendation.json`. Each recommendation item already has two roles:

- `displayName`: authored human-facing item text.
- `name` + `grams`: machine-readable values for `recommend.py log`.
- optional item nutrition such as `kcal`: authored/read-only display metadata.

The Dashboard nutrition panel currently renders fresh loggable rows through `NutritionLoggableItem` and also appends a grams-only amount label. That makes the visible row emphasize grams even when Hermes authored `displayName` with serving units, such as `香蕉 1 根 (120g)` or `蛋白粉 1 勺 (30g)`.

The same row already has a kcal slot for legacy panel suggestions, but recommendation snapshots currently flatten kcal to `nil`, so Hermes-authored item calories disappear even when the recommendation contract carries them.

## Goals / Non-Goals

**Goals:**

- Preserve Hermes-authored `displayName` exactly in "现在可以吃" rows.
- Preserve Hermes-authored per-item `kcal` when present and show it beside the item.
- Keep click and digit-key logging bound to `name` and `grams`.
- Cover the behavior with a focused regression test using a serving-unit display label and kcal.

**Non-Goals:**

- Do not add recommendation schema fields or bump `schemaVersion`.
- Do not read `foods.json` or derive units/calories in MalDaze.
- Do not change Hermes recommendation generation, plan calculations, or `recommend.py log` semantics.

## Decisions

- Render the authored item label as the visible quantity source. The UI may keep a grams fallback only when the authored `displayName` does not already contain the item's grams text, but it must not replace the label with grams-only text.
- Decode optional `NutritionRecommendationItem.kcal` and pass it through to `NutritionLoggableItem.kcal`. The existing row UI already knows how to render kcal for loggable suggestions; stale/non-clickable recommendation rows should use the same optional metadata when available.
- Keep `NutritionLoggableItem.displayName` sourced from `NutritionRecommendationItem.displayName` and logging sourced from `name` + `grams`. This preserves the existing separation between display and logging.
- Add model-level regression coverage for serving-unit `displayName`, kcal preservation, and logging grams. The view change is narrow enough that source-level or focused unit verification is sufficient; manual QA can confirm the visual row.

## Risks / Trade-offs

- [Risk] A Hermes-authored `displayName` omits quantity text, leaving the row less informative if the UI hides grams unconditionally. -> Mitigation: use a small display helper so grams remain available as fallback only when they are not already present in `displayName`.
- [Risk] Existing Hermes snapshots do not yet include item `kcal`, so MalDaze still cannot display calories for those snapshots. -> Mitigation: treat `kcal` as optional and document that Hermes must publish it for item calories to appear.
- [Risk] MalDaze starts duplicating Hermes unit or nutrition logic. -> Mitigation: never parse `foods.json` or synthesize serving units/calories locally; only preserve authored fields.
