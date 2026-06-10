## Context

MalDaze is intended to display Hermes nutrition facts and Hermes-authored recommendations while performing only the write actions explicitly defined by Hermes contracts. The current active nutrition recommendation change established `daily_log.json` as the facts contract and `recommendation.json` as the only user-visible recommendation contract.

The implementation drifted in two ways:

- `morning-briefing.py` still contains unused legacy planner code (`get_diet_plan()` and `plan_engine.py --full-day`) even though Morning Briefing no longer uses it for display. That dead code is misleading enough that Hermes can infer it is part of the production flow.
- `morning-briefing.py` writes an unavailable recommendation snapshot when no Hermes authoring step runs. That makes a deterministic script look like a recommendation owner and pollutes `recommendation.json`, whose meaning should be "Hermes authored or approved this user-visible recommendation state."
- Daily training/rest classification is hidden behind `recommend.py auto`, a broad nutrition engine command. The same fact is needed by nutrition, sleep, and morning briefing, so it should have a named program boundary.

## Goals / Non-Goals

**Goals:**

- Make the Morning Briefing deterministic script a facts refresh step only.
- Ensure user-visible food recommendations are written only by Hermes authoring flows.
- Remove dead planner code from Morning Briefing production code.
- Add a standalone `day_classification.py` program that owns training/rest day classification and related workout split synchronization.
- Keep `recommend.py auto` only as a compatibility wrapper during migration.
- Add tests that prevent deterministic scripts from writing recommendation placeholders or calling planner code.

**Non-Goals:**

- Do not redesign `plan_engine.py`; it remains a candidate/context tool for Hermes.
- Do not remove `recommendation.json state: "unavailable"` entirely. The state remains valid when Hermes authoring explicitly decides not to recommend.
- Do not change food logging, inventory deduction, undo, or macro target formulas beyond moving day classification ownership.

## Decisions

### Decision 1: Morning Briefing script refreshes facts only

`~/.hermes/scripts/morning-briefing.py` SHALL run day classification and panel refresh, then print facts/status. It SHALL NOT import `recommendation_store`, SHALL NOT write `recommendation.json`, and SHALL NOT call `plan_engine.py`.

Alternative considered: keep writing `state: "unavailable"` from the deterministic script with better wording. Rejected because it still makes a non-author script mutate the recommendation source of truth.

### Decision 2: Hermes authoring writes recommendation snapshots

When Hermes sends text that tells the user what to eat next, the same authored content must be written to `recommendation.json`. This applies to scheduled Morning Briefing delivery, manual "rerun morning briefing", and Feishu nutrition conversations after logging or state updates.

The deterministic script can provide facts for the authoring step, but the AI authoring step owns the recommendation write.

Alternative considered: make MalDaze synthesize recommendations from remaining macros when the file is missing. Rejected because it would create client-side recommendation logic and reintroduce shadow recommendation state.

### Decision 3: Add `day_classification.py` as a first-class program

Create `~/.hermes/data/nutrition/day_classification.py`.

Production call:

```bash
python3 day_classification.py
```

It performs the current `recommend.py auto` responsibility:

- load `profile.json`
- read `training_log.json` as the single source of truth for prior strength training days
- classify today's nutrition day as `training` or `rest`
- assign or clear `daily_log.workout_split`
- ensure today's `training_log` strength record exists when classified as training
- atomically update `daily_log.json`, including refreshed panel facts through existing nutrition helpers
- print structured JSON for callers

`recommend.py auto` remains as a deprecated wrapper that delegates to this program/module so old scripts do not break immediately. New production callers MUST use `day_classification.py`.

Alternative considered: keep `recommend.py auto` but document it better. Rejected because the command name hides a cross-domain daily classification responsibility inside the food recommendation engine.

### Decision 4: Share logic, avoid duplicating persistence

The new day classification program may import reusable helpers from `recommend.py` during the migration, but the classification algorithm should live behind the new program boundary. If importing `recommend.py` creates CLI side effects or circular dependencies, extract a small shared module such as `day_classification_core.py` in the same directory.

The implementation must preserve existing locking/atomic write behavior for `daily_log.json`. It must not create a second day-type store in profile/defaults/cache.

### Decision 5: Test names describe production boundaries, not "no-agent"

Tests may describe deterministic scripts or authoring absence, but production code and fixtures should avoid introducing "no-agent" as a domain concept. Prefer names such as `test_morning_briefing_does_not_write_recommendation_snapshot`.

## Risks / Trade-offs

- Day classification extraction could change subtle `training_log` / `workout_split` behavior → Mitigate with fixture tests covering first training day, rest day after training, existing same-day training record, and workout split alternation.
- Existing scripts or habits may still call `recommend.py auto` → Mitigate with a compatibility wrapper and documentation migration; tests should assert Morning Briefing no longer calls it directly.
- Hermes may still reply with food advice without writing `recommendation.json` → Mitigate by updating nutrition skill rules and adding QA that compares the written snapshot with the reply path.
- Deterministic Morning Briefing may now leave stale/missing recommendations visible in MalDaze → This is intentional; stale/missing is safer than a script-authored placeholder. Hermes authoring must write a fresh snapshot when it actually gives advice.

## Migration Plan

1. Add failing tests for Morning Briefing boundaries: no `recommendation_store` import/use, no `get_diet_plan`, no `plan_engine.py`, and no recommendation file write during deterministic script execution.
2. Add failing tests for `day_classification.py` behavior using isolated nutrition data directories.
3. Implement `day_classification.py` and delegate `recommend.py auto` to the new boundary.
4. Update `morning-briefing.py` to call `day_classification.py` and `recommend.py refresh-panel`; remove recommendation writes and legacy planner helper.
5. Update nutrition skill docs so rerun Morning Briefing plus any user-visible food advice must write `recommendation.json` from the Hermes authoring step.
6. Update OpenSpec/manual QA docs to remove production "no-agent" semantics.
7. Run focused Hermes tests and OpenSpec validation.

Rollback strategy: revert callers to `recommend.py auto` and restore the prior Morning Briefing script from git if the new classifier breaks day facts. Do not roll back by allowing deterministic planner recommendations to be displayed.

## Open Questions

- Should the Hermes authoring runner for scheduled Morning Briefing be a separate executable in this change, or should this change only define and document the required authoring write path for the existing Hermes runtime?
- Should `recommend.py auto` print a deprecation warning to stderr, or remain silent to avoid breaking JSON-only callers?
