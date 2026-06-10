## Why

MalDaze updates the nutrition desk panel only when Hermes writes a fresh `recommendation.json`. Morning Briefing already closes this loop via scripted `morning_briefing_nutrition.py`, but free-form Hermes nutrition conversations often run `plan_engine.py` and reply with menu text without calling `nutrition_authoring_publish.py publish --stdin`. The result is a stale recommendation snapshot and a desk pet that does not reflect the advice the user just received.

Prior OpenSpec work established ownership and file contracts; the remaining gap is **agent turn discipline**: Hermes must recognize when a turn includes user-visible planning of today's remaining food and must not treat the turn as complete until publish + status verification succeed. This must be achieved through skill procedure and authoring compliance, not gateway auto-publish patches.

## What Changes

- Introduce a **Menu Turn** invariant in the nutrition-menu skill: when a turn semantically includes user-visible planning of today's remaining food, Hermes MUST complete `publish --stdin` and `status` (`ok: true`) before claiming the advice is synced to MalDaze.
- Require **LLM semantic classification** of Menu Turn intent inside the skill (with examples and counter-examples). Menu Turn detection MUST NOT rely on keyword/pattern routing alone; model-router nutrition patterns remain routing-only and are not the Menu Turn gate.
- Strengthen turn-end checklist and ordering: facts mutations first, then plan, then author, then publish, then status; forbid claiming menu advice is final while `recommendation.json` is stale.
- Rename nutrition-domain **Feishu-specific identifiers** to ingress-agnostic Hermes naming (`feishu_nutrition` → `hermes_nutrition`, test/module/doc names, skill copy).
- Add regression tests and manual QA for Menu Turn publish discipline on isolated fixtures.
- **Non-goals**: gateway hooks that auto-write `recommendation.json`; MalDaze client-side recommendation fallback; relaxing MalDaze fresh/stale gates.

## Capabilities

### New Capabilities

- `nutrition-menu-turn`: Semantic Menu Turn classification rules, publish/status completion gate, and ingress-agnostic Hermes agent workflow for planning today's remaining food.
- `nutrition-recommendation-contract`: Nutrition recommendation snapshot requirements including `source.kind: hermes_nutrition`, Menu Turn write obligations, and Feishu-name removal in contract language.
- `hermes-nutrition-qa`: Isolated QA for Hermes nutrition authoring boundaries (replaces nutrition-specific `feishu` naming in tests/docs).

### Modified Capabilities

- `hermes-morning-briefing`: Clarify that Morning Briefing scripted publish remains separate from Menu Turn; no regression to facts-only briefing.
- None for `integration-feishu-qa` at spec-id level (that spec covers broader Feishu-proxy day-reminder/learning QA). Nutrition QA moves to `hermes-nutrition-qa`.

## Impact

- Hermes skill/docs:
  - `~/.hermes/skills/nutrition/nutrition-menu/SKILL.md`
  - `~/.hermes/data/nutrition/README.md`
- Hermes scripts/tests:
  - `~/.hermes/data/nutrition/nutrition_authoring_publish.py` (default `source.kind`)
  - `~/.hermes/tests/nutrition/test_integration_feishu_nutrition_qa.py` → rename to `test_integration_hermes_nutrition_qa.py`
  - `~/.hermes/tests/nutrition/test_nutrition_authoring_publish.py`
- MalDaze docs only (no app code changes expected):
  - `docs/integrations/hermes.md`
  - `docs/integrations/features/nutrition-today-panel.md`
- Cross-repo contract pointer in `docs/integrations/hermes.md` remains canonical for MalDaze.
