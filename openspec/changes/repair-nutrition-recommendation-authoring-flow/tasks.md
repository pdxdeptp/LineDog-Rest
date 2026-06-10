## 1. Git Safety And Baseline

- [x] 1.1 Run `git status --short --branch` in `/Users/cpt/Public/MalDaze` and `/Users/cpt/.hermes`; confirm no unrelated live changes will be overwritten.
- [x] 1.2 If applying in current checkout, create or confirm an appropriate checkpoint before editing Hermes production scripts.
- [x] 1.3 Run `openspec validate repair-nutrition-recommendation-authoring-flow --strict` before implementation and fix any proposal/spec issues first.

## 2. Morning Briefing Regression Tests

- [x] 2.1 Add a failing test in `/Users/cpt/.hermes/tests/nutrition/test_morning_briefing_nutrition.py` asserting `morning-briefing.py` source does not define `get_diet_plan`.
- [x] 2.2 Add a failing test asserting `morning-briefing.py` source does not reference `plan_engine.py` or Morning Briefing `--full-day` planner calls.
- [x] 2.3 Add a failing isolated execution test asserting deterministic `morning-briefing.py` does not create `recommendation.json` when none exists.
- [x] 2.4 Add a failing isolated execution test asserting deterministic `morning-briefing.py` leaves an existing `recommendation.json` byte-for-byte unchanged.
- [x] 2.5 Run the new Morning Briefing tests and confirm they fail for the current production code before implementation.

## 3. Day Classification Tests

- [x] 3.1 Add `/Users/cpt/.hermes/tests/nutrition/test_day_classification.py` with isolated fixture helpers for `profile.json`, `daily_log.json`, `training_log.json`, and minimal `foods.json`.
- [x] 3.2 Add a failing test that `python3 day_classification.py` classifies first known day as `training`, writes `daily_log.day_type`, creates panel facts, and does not write `recommendation.json`.
- [x] 3.3 Add a failing test that rhythm day after yesterday's training classifies as `rest`, clears `daily_log.workout_split`, and does not create a same-day `is_training: true` record.
- [x] 3.4 Add a failing test that a training day alternates `workout_split` from the latest prior strength record and syncs the same split into today's `training_log` record.
- [x] 3.5 Add a failing compatibility test that `recommend.py auto` delegates to the standalone classifier and returns the same payload shape.
- [x] 3.6 Run the new day classification tests and confirm they fail before implementation.

## 4. Standalone Day Classification Implementation

- [x] 4.1 Create `/Users/cpt/.hermes/data/nutrition/day_classification.py` as the production entrypoint for `python3 day_classification.py`.
- [x] 4.2 Move or extract the current `cmd_auto_day` classification algorithm behind the new program boundary without duplicating the day-type SSOT in profile/defaults/cache.
- [x] 4.3 Preserve existing `training_log.json` behavior: read latest `is_training: true` date, ignore `is_training: false` activities for rhythm, create today's default 500 kcal strength record only on training days, and keep existing same-day strength records instead of duplicating them.
- [x] 4.4 Preserve existing `workout_split` behavior: training days alternate chest/back_legs from prior strength record; rest days clear `daily_log.workout_split`.
- [x] 4.5 Ensure `day_classification.py` uses the same locked/atomic daily-log update path and leaves a valid `daily_log.panel` after classification.
- [x] 4.6 Update `recommend.py auto` to be a compatibility wrapper around the standalone classifier instead of owning separate classification logic.
- [x] 4.7 Run `/Users/cpt/.hermes/tests/nutrition/test_day_classification.py` and make the new tests pass.

## 5. Morning Briefing Production Cleanup

- [x] 5.1 Update `/Users/cpt/.hermes/scripts/morning-briefing.py` so nutrition facts refresh invokes `day_classification.py` instead of `recommend.py auto`.
- [x] 5.2 Remove `write_unavailable_nutrition_recommendation()` and any `recommendation_store` import/use from `morning-briefing.py`.
- [x] 5.3 Remove `get_diet_plan()` and all deterministic Morning Briefing `plan_engine.py --full-day` planner code from `morning-briefing.py`.
- [x] 5.4 Keep Morning Briefing output focused on facts/status when no Hermes nutrition authoring step has run; do not emit "no-agent" domain language.
- [x] 5.5 Run the Morning Briefing regression tests and make them pass.

## 6. Hermes Authoring Workflow Documentation

- [x] 6.1 Update `/Users/cpt/.hermes/skills/nutrition/nutrition-menu/SKILL.md` so production Morning Briefing refresh uses `python3 day_classification.py` followed by facts refresh/status read.
- [x] 6.2 Update the nutrition skill so "重新跑晨报" plus any user-visible food advice requires Hermes to write the same `summary` and `suggestions` to `recommendation.json` with `source.kind: "morning_briefing"`.
- [x] 6.3 Update the nutrition skill so every Feishu nutrition reply containing next-step food advice writes `recommendation.json` with post-log `basedOn.dailyLogPanelUpdatedAt`.
- [x] 6.4 Remove production "no-agent" terminology from nutrition skill/docs; if a test needs that concept, rename it to deterministic-script/no-author terminology.
- [x] 6.5 Update `/Users/cpt/.hermes/data/nutrition/README.md` to document `day_classification.py`, deprecate production use of `recommend.py auto`, and clarify that deterministic scripts do not write recommendation snapshots.

## 7. Integration QA And Contract Coverage

- [x] 7.1 Add or update Feishu nutrition QA tests so an authored nutrition reply writes an available `recommendation.json` snapshot in isolated fixtures.
- [x] 7.2 Add or update QA tests so a nutrition update without authored food advice does not fake a fresh available recommendation.
- [x] 7.3 Add a QA/source assertion that production Morning Briefing instructions reference `day_classification.py` and not `recommend.py auto`.
- [x] 7.4 Ensure tests never mutate live `/Users/cpt/.hermes/data/nutrition/*.json` while validating these flows.

## 8. OpenSpec And Integration Docs

- [x] 8.1 Update active nutrition OpenSpec/docs that mention Morning Briefing unavailable placeholders so they match the new deterministic-script non-ownership model.
- [x] 8.2 Update `/Users/cpt/Public/MalDaze/docs/integrations/hermes.md` and related nutrition panel docs only if their described contract changes.
- [x] 8.3 Confirm MalDaze does not generate, cache, or directly write `recommendation.json`, and still treats missing/stale/unavailable states according to the contract.

## 9. Verification

- [x] 9.1 Run `openspec validate repair-nutrition-recommendation-authoring-flow --strict`.
- [x] 9.2 Run focused Hermes tests: `python3 -m pytest tests/nutrition/test_day_classification.py tests/nutrition/test_morning_briefing_nutrition.py tests/nutrition/test_recommendation_store.py -q`.
- [x] 9.3 Run relevant existing Hermes nutrition regression tests: `python3 -m pytest tests/nutrition/test_refresh_panel.py tests/nutrition/test_refresh_panel_cmd.py tests/nutrition/test_workout_split.py -q`.
- [x] 9.4 Run Python compilation checks: `python3 -m py_compile data/nutrition/day_classification.py data/nutrition/recommend.py data/nutrition/recommendation_store.py scripts/morning-briefing.py`.
- [x] 9.5 Run `git diff --check` in both `/Users/cpt/Public/MalDaze` and `/Users/cpt/.hermes`.
- [x] 9.6 Manually inspect live nutrition data after tests to confirm no fixture or smoke command modified the user's real `daily_log.json`, `training_log.json`, or `recommendation.json`.
