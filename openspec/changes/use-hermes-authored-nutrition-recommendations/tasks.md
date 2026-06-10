## 1. OpenSpec And Contract Alignment

- [x] 1.1 Update `add-nutrition-today-panel` artifacts to mark Python `panel.suggestions` as superseded by `recommendation.json`
- [x] 1.2 Decide and document first-version compatibility for `daily_log.panel.suggestions` as empty array versus removed field
- [x] 1.3 Update integration docs to name `daily_log.json` as nutrition facts and `recommendation.json` as user-visible recommendation

## 2. Hermes Recommendation Store

- [x] 2.1 Add failing tests for writing a valid `recommendation.json` snapshot with `source`, `basedOn`, `summary`, and loggable items
- [x] 2.2 Add failing tests that invalid loggable item names or non-positive grams are rejected without replacing the existing snapshot
- [x] 2.3 Implement `recommendation_store.py` load/validate/write/unavailable helpers with atomic writes
- [x] 2.4 Add fixtures for available, stale, missing, unavailable, and invalid recommendation snapshots

## 3. Hermes Facts Engine Migration

- [x] 3.1 Add failing tests that `recommend.py refresh-panel` updates metrics but does not generate user-visible suggestions
- [x] 3.2 Remove or disable `_build_panel_suggestions` as a MalDaze recommendation source while preserving targets/consumed/remaining/dayLabel
- [x] 3.3 Update `integration_smoke.py` nutrition checks for facts panel plus recommendation contract states
- [x] 3.4 Update nutrition README and skill rules so `plan_engine.py` output is candidate context only

## 4. Hermes Recommendation Writers

- [x] 4.1 Update nutrition-menu skill/workflow so every Feishu nutrition reply that recommends food writes `recommendation.json`
- [x] 4.2 Add or update Feishu integration QA covering log followed by fresh recommendation snapshot
- [x] 4.3 Refactor Morning Briefing nutrition flow so user-visible nutrition recommendation is Hermes-authored before writing `recommendation.json`
- [x] 4.4 Add tests or smoke evidence that planner-only Morning Briefing candidates are not published as fresh recommendations

## 5. MalDaze Recommendation Reader

- [x] 5.1 Add failing Swift tests for `NutritionRecommendationContract` decoding schemaVersion 1 snapshots
- [x] 5.2 Add failing Swift tests for fresh, stale, missing, unavailable, and invalid recommendation states against `daily_log.panel.updatedAt`
- [x] 5.3 Implement recommendation contract reader and file watcher for `recommendation.json`
- [x] 5.4 Update `NutritionTodayViewModel` to combine daily facts from `daily_log.json` with recommendations from `recommendation.json`

## 6. MalDaze UI And Logging

- [x] 6.1 Update `NutritionTodayPanelView` so “现在可以吃” renders recommendation summary, rationale, warnings, and items from `recommendation.json`
- [x] 6.2 Enable click and 1-9 digit logging only for fresh `loggable: true` recommendation items
- [x] 6.3 Disable recommendation actions and show explicit copy for stale, missing, unavailable, or invalid recommendation states
- [x] 6.4 Ensure successful `recommend.py log` reloads facts immediately and leaves recommendations stale until Hermes writes a fresh snapshot

## 7. Verification And QA

- [x] 7.1 Run Hermes nutrition tests and integration smoke for facts panel plus recommendation contract
- [x] 7.2 Run focused MalDaze Swift tests for nutrition contract, view model, and UI source assertions
- [x] 7.3 Update manual QA for Morning Briefing writes, Feishu log writes, stale-after-log, and missing-file behavior
- [x] 7.4 Run `openspec validate use-hermes-authored-nutrition-recommendations --strict`
