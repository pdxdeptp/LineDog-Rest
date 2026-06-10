## Why

The nutrition recommendation integration currently mixes three responsibilities: deterministic morning facts refresh, Hermes-authored food recommendation, and legacy planner candidates. This caused Hermes to interpret a temporary fallback as production behavior and allowed unused `plan_engine --full-day` code to remain in the morning briefing path.

The day classification flow is also hidden behind `recommend.py auto`, which makes a first-class daily fact decision look like an incidental subcommand on the nutrition record engine. Splitting day classification into an explicit program clarifies ownership, testability, and future reuse by morning briefing, sleep tracking, and Feishu nutrition flows.

## What Changes

- Remove production "no-agent" recommendation behavior from Morning Briefing. Deterministic scripts may refresh facts, but MUST NOT write `recommendation.json` merely because an AI author step did not run.
- Remove unused Morning Briefing diet planner helper code, including stale `get_diet_plan()` and any `plan_engine.py --full-day` call in `morning-briefing.py`.
- Require Hermes nutrition authoring flows to write `recommendation.json` whenever they reply with a user-visible next-step food recommendation, including after "rerun morning briefing" and after Feishu nutrition updates.
- Clarify that `recommendation.json state: "unavailable"` is reserved for an explicit Hermes-authored decision, not for deterministic-script placeholders.
- Introduce a standalone day classification program that owns training/rest day classification and writes the daily facts needed by nutrition and sleep flows.
- Deprecate direct use of `recommend.py auto` by Morning Briefing and Hermes skills; keep any old subcommand only as a compatibility wrapper during migration.
- Add regression tests proving deterministic Morning Briefing does not call `plan_engine.py`, does not define legacy planner helpers, and does not write recommendation snapshots.

## Capabilities

### New Capabilities
- `nutrition-day-classification`: Standalone training/rest day classification program and contract, replacing direct production use of `recommend.py auto`.
- `nutrition-recommendation-contract`: Additional ownership constraints for the active recommendation snapshot contract, especially deterministic-script non-ownership and authored unavailable states.

### Modified Capabilities
- `hermes-morning-briefing`: Morning Briefing refreshes nutrition facts through explicit day classification and panel refresh, but does not publish recommendations unless Hermes authoring writes the same recommendation snapshot.
- `integration-feishu-qa`: Feishu/Hermes nutrition replies that include next-step food advice must write the same advice to `recommendation.json`.

## Impact

- Hermes scripts:
  - `~/.hermes/scripts/morning-briefing.py`
  - new standalone day classification entrypoint under `~/.hermes/data/nutrition/`
- Hermes nutrition engine:
  - `~/.hermes/data/nutrition/recommend.py`
  - `~/.hermes/data/nutrition/recommendation_store.py`
  - `~/.hermes/data/nutrition/README.md`
- Hermes skill docs:
  - `~/.hermes/skills/nutrition/nutrition-menu/SKILL.md`
- Tests:
  - `~/.hermes/tests/nutrition/test_morning_briefing_nutrition.py`
  - new tests for standalone day classification
- MalDaze frontend behavior should not need code changes unless tests reveal a freshness/display gap; existing nutrition write interactions remain limited to explicitly contracted Hermes commands.
