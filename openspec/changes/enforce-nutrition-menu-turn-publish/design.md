## Context

MalDaze reads nutrition facts from `daily_log.json` and user-visible advice from `recommendation.json`. A recommendation is **fresh** only when `date`, `basedOn.dailyLogPanelUpdatedAt`, and `basedOn.recordsCount` align with the current daily log panel. MalDaze watches both files via FSEvents and intentionally does not synthesize recommendations when the snapshot is stale or missing.

Morning Briefing closes the publish loop with `morning_briefing_nutrition.py`. Hermes agent nutrition conversations use a multi-step LLM workflow (`status` → `plan_engine` → author → `nutrition_authoring_publish.py publish --stdin` → `status`). Live failures show the agent often completes steps 1–3 and replies to the user while skipping 4–5.

`model-router` already classifies nutrition-related messages with regex patterns for **tier routing** (Flash vs Pro). Those patterns are a poor Menu Turn gate because they are keyword-based, ingress-agnostic only for routing, and fire before the agent understands turn semantics.

Historical nutrition naming still uses Feishu-specific identifiers (`feishu_nutrition`, `test_integration_feishu_nutrition_qa.py`, skill headings referencing Feishu). Feishu is one ingress channel, not the authoring owner.

## Goals / Non-Goals

**Goals:**

- Define **Menu Turn** as a semantic agent obligation, not a router keyword match.
- Make the nutrition-menu skill the authoritative procedure for Menu Turn classification, ordering, publish, and status verification.
- Ensure any ingress (Feishu DM, CLI, TUI, future channels) that produces user-visible remaining-food advice writes a fresh `recommendation.json` before the turn is treated as complete.
- Rename nutrition-domain Feishu-specific identifiers to `hermes_nutrition` / Hermes-agent language.
- Add isolated QA proving Menu Turn publish discipline.

**Non-Goals:**

- Gateway plugins or hooks that auto-publish plan candidates or silently repair stale snapshots.
- MalDaze changes that relax fresh gates or locally generate recommendations.
- Renaming the broad `integration-feishu-qa` spec id (covers day-reminder and learning proxy QA unrelated to nutrition).
- Replacing LLM authoring with deterministic `plan_engine` output for user-visible menus.

## Decisions

### Decision 1: Menu Turn gate lives in the nutrition-menu skill (Direction A)

The skill SHALL define a **Menu Turn** and require the loaded agent to apply semantic judgment before ending the turn.

**Menu Turn (semantic YES)** examples:

- User asks what to eat next given today's remaining quota.
- User asks to plan/replan remaining meals for today after logging food.
- Agent replies with specific next-step food items the user should eat today.

**Menu Turn (semantic NO)** examples:

- Pure logging/undo without next-step menu advice.
- Status/progress only.
- Weight/day-type changes without menu advice.
- Historical food questions unrelated to today's remaining plan.

The agent MUST explicitly decide Menu Turn yes/no at turn planning time (skill instructs a short internal classification step). Keyword lists MAY appear only as non-authoritative examples; they MUST NOT be the sole trigger.

Alternative considered: reuse `model-router` `nutrition_patterns` as Menu Turn detector. Rejected because routing regexes are keyword-based, run outside the nutrition skill context, and cannot distinguish「记录肯德基」from「记录后帮我规划剩余」.

Alternative considered: gateway auto-publish after `plan_engine`. Rejected per product direction.

### Decision 2: Turn completion requires publish + status for Menu Turn

When Menu Turn = YES:

1. Finish facts mutations (`log`, `undo`, `day_classification`, `refresh-panel` as needed).
2. Run `plan_engine` for candidates; LLM filters/authors final menu.
3. Run `nutrition_authoring_publish.py publish --stdin` with the same authored summary/suggestions shown to the user.
4. Run `nutrition_authoring_publish.py status`; exit `ok: true` and `state: available` before telling the user the desk pet is synced.
5. MUST NOT run facts-mutating commands after publish in the same turn.

If Menu Turn = YES but reliable advice cannot be authored, write `unavailable` with reason instead of leaving a stale available snapshot.

Alternative considered: trust `recommend.py status` envelope only. Accepted as supplementary signal, but `nutrition_authoring_publish.py status` remains the publish gate because it reflects post-publish disk state.

### Decision 3: Semantic classification is LLM-owned, with skill-authored rubric

The skill SHALL include:

- A **Menu Turn rubric** (YES/NO criteria + counter-examples).
- A required **pre-reply checklist** for Menu Turn YES.
- Explicit rule: **do not send final menu text to the user until publish + status succeed** (or unavailable is written).

No new gateway classifier service in this change. Optional future work: a dedicated Hermes tool for publish (Direction B) is out of scope here.

### Decision 4: Rename nutrition Feishu identifiers to Hermes naming

| Old | New |
|-----|-----|
| `source.kind: feishu_nutrition` | `source.kind: hermes_nutrition` |
| `test_integration_feishu_nutrition_qa.py` | `test_integration_hermes_nutrition_qa.py` |
| Skill headings「Feishu / Hermes 对话」|「Hermes agent 对话」|
| QA class names `FeishuNutrition*` | `HermesNutrition*` |

Keep Feishu mentions only where describing an ingress channel (e.g.「飞书 DM 也是 Hermes ingress 之一」), not as the recommendation owner or `source.kind`.

Runtime data: existing `recommendation.json` with `feishu_nutrition` remains readable; new writes use `hermes_nutrition`. No migration script required for live files in v1.

### Decision 5: Extract nutrition QA to `hermes-nutrition-qa` spec

Nutrition authoring QA moves out of Feishu-named tests/docs into `hermes-nutrition-qa` requirements. `integration-feishu-qa` main spec stays for day-reminder/learning proxy chains.

## Risks / Trade-offs

- **[Risk] LLM still skips publish despite skill text** → Mitigate with explicit ordering rule (no user menu text before status), `recommendation` envelope visibility after `log`/`status`, integration tests, and manual QA script mirroring the live failure path.
- **[Risk] Over-triggering Menu Turn on casual food chat** → Mitigate with semantic NO examples and distinction between「今天剩余怎么吃」vs general nutrition trivia.
- **[Risk] Under-triggering when user phrasing is indirect** → Mitigate with rubric emphasizing user intent (remaining quota planning), not fixed keywords.
- **[Risk] `hermes_nutrition` rename breaks tests/docs grep habits** → Mitigate with renamed test module and one-time doc sweep limited to nutrition domain.
- **[Trade-off] No mechanical enforcement** → Stale snapshots remain possible if the agent disobeys skill; acceptable per product choice; MalDaze stale UX correctly signals the miss.

## Migration Plan

1. Update nutrition-menu skill with Menu Turn rubric, checklist, and renamed Hermes terminology.
2. Update `nutrition_authoring_publish.py` defaults and docs to `hermes_nutrition`.
3. Rename nutrition integration test file and fixtures; keep isolated `NUTRITION_DATA_DIR` temp dirs.
4. Update MalDaze integration docs (`hermes.md`, nutrition-today-panel.md) to reference Menu Turn and `hermes_nutrition`.
5. Run Hermes nutrition unit/integration tests and `openspec validate`.
6. Manual QA: Hermes agent Menu Turn conversation → `status ok:true` → MalDaze panel fresh within FSEvents debounce.

Rollback: revert skill/docs/tests; no MalDaze code rollback expected.

## Open Questions

- Should the skill require a single combined terminal step (heredoc publish) in examples to reduce skipped publish commands?
- Should live `recommendation.json` with legacy `feishu_nutrition` be rewritten on next publish only (recommended) or bulk-migrated once?
