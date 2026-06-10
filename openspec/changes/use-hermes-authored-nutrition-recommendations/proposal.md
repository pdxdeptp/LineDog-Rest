## Why

MalDaze 饮食面板目前展示 `recommend.py` 直接用 `plan_engine` 生成的 `daily_log.panel.suggestions`，这会出现数学上接近目标但人类体验明显离谱的建议（例如 900g 酸奶）。用户真正需要的是：桌宠展示 Hermes 已经给用户推荐过、并经过上下文/偏好/常识把关的饮食建议快照，而不是前端或底层 Python 再跑一条独立推荐路径。

## What Changes

- 新增 `~/.hermes/data/nutrition/recommendation.json` 作为“用户可见饮食建议”的只读展示契约；`daily_log.json` 继续作为 records、targets、consumed、remaining 的营养事实契约。
- **BREAKING**：MalDaze 不再把 `daily_log.panel.suggestions` 当作“现在可以吃”的来源；桌宠建议区只展示 `recommendation.json` 中的当前快照。
- **BREAKING**：`recommend.py refresh-panel` / `_attach_panel` 不再生成用户可见 `suggestions`；`recommend.py` 只负责记录、计算、试算和营养状态，不负责最终推荐文案或菜单选择。
- Hermes 在每次向用户给出饮食建议时写入 `recommendation.json`，包括晨报饮食建议，以及飞书/Hermes 对话里记录食物、更新状态后给出的下一步建议。
- 推荐快照必须声明它基于哪一天、哪次 `daily_log` 状态、由什么来源写入、是否仍新鲜；MalDaze 在快照过期或缺失时显示“等待 Hermes 更新建议”，不得本地回退到 `plan_engine`。
- `plan_engine.py` 可继续作为 Hermes 生成候选方案的内部工具，但其原始输出不得绕过 Hermes 推荐写入流程直接展示给桌宠。
- 当前 `add-nutrition-today-panel` change 中关于 Python 基线 `suggestions` 的设计与规格被本 change 修正；实现时需同步更新相关 OpenSpec、集成文档与 Hermes skill 规则。

## Capabilities

### New Capabilities

- `nutrition-recommendation-contract`: Hermes-authored nutrition recommendation snapshot file, freshness semantics, writer rules, and MalDaze read-only display behavior.

### Modified Capabilities

- `hermes-morning-briefing`: Morning briefing nutrition recommendation output must also write/update the shared nutrition recommendation snapshot.

## Impact

- **Hermes**: `~/.hermes/data/nutrition/recommend.py`, `plan_engine.py` call sites, `morning-briefing.py`, nutrition-menu skill, tests, integration smoke, and the new `recommendation.json` contract/writer helper.
- **MalDaze**: `NutritionToday/` contract decoding, view model, UI suggestion section, file watching/freshness handling, tests, and docs. Metrics and records still read from `daily_log.json`; user-visible recommendations read from `recommendation.json`.
- **Docs/OpenSpec**: revise `add-nutrition-today-panel` assumptions, `docs/integrations/features/nutrition-today-panel.md`, `docs/integrations/hermes.md`, and manual QA for stale/missing recommendations.
- **Non-goals**: building a full meal-planning AI inside MalDaze; letting MalDaze compute or filter suggestions; making `recommend.py` call an LLM directly unless Hermes architecture chooses that as the writer path.
