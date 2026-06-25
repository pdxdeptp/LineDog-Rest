# Design · Hermes（`~/.hermes`）

路径：`data/nutrition/`

> Superseded alignment: `use-hermes-authored-nutrition-recommendations` changes `_refresh_panel` to facts/metrics only. `panel.suggestions` remains `[]` for schema compatibility; user-visible recommendations are written to `recommendation.json` by Hermes authoring flows.

## `_refresh_panel(daily_log) -> dict`

在 `_update_daily_log` 的 `updater` 返回前或写盘后调用：

1. `targets = get_targets(daily_log)`
2. `total, consumed, remaining = calc_remaining(daily_log, targets)`
3. `day_label = {"training": "训练日", "rest": "休息日"}[daily_log["day_type"]]`
4. `suggestions = []` — compatibility only; do not generate user-visible recommendations here
5. 返回附加到 `data["panel"]`（含 `targetBreakdown` 诊断层；`targets.kcal = formula_base + activity_extra`，校准不计入目标，见 Hermes `data/nutrition/README.md` § get_targets）：

```json
{
  "schemaVersion": 1,
  "updatedAt": "<ISO8601 local>",
  "dayLabel": "休息日",
  "targets": { "kcal", "protein_g", "carbs_g", "fat_g", "sodium_mg" },
  "consumed": { ... },
  "remaining": { ... },
  "suggestions": [],
  "calorieSlack": 50
}
```

## `_build_panel_suggestions`（superseded）

- 不再作为 MalDaze 推荐来源实现或调用。
- `plan_engine` 可继续为 Hermes authoring path 产生候选上下文，但候选必须经过 Hermes 推荐流程写入 `recommendation.json` 后才可展示。
- `recommend.py refresh-panel` 和 mutating 写入只维护 `targets` / `consumed` / `remaining` / `dayLabel` / `updatedAt` 等 facts/metrics，并保持 `panel.suggestions: []`。

## Mutating 命令挂钩

必须在以下路径后刷新 `panel`（同一 `_update_daily_log` 写）：

- `cmd_log` · `cmd_log_custom` · `cmd_undo` · `cmd_reset`
- `cmd_trained` · `cmd_set_day` · `cmd_auto_day`
- （可选）`cmd_set_weight` — targets 变

## 归档

`_load_daily_log` 轮转写 `history/{date}.json` 时：**不**写入 `panel` 键。

## refresh-panel（S4）

```bash
python3 recommend.py refresh-panel
```

- 只重算 `panel`，不碰 `records`。
- 晨报、smoke 前置、调试使用。

## integration_smoke（S3）

`check_nutrition_panel()`：读 `daily_log.json`，`panel.schemaVersion == 1`；无 panel 时 `ok: false`（或 smoke 前 seed `refresh-panel`）。

## 晨报

`morning-briefing.py` 营养 facts 段后可调用 `refresh-panel` 或 `_refresh_panel` 更新 metrics。若晨报包含用户可见饮食建议，Hermes authoring path 必须同时写入 `recommendation.json`；planner-only 候选不得作为 fresh recommendation 发布。

## Skill 规则（`nutrition-menu/SKILL.md`）

- 新增：**禁止**手改 `daily_log.json`；`panel` 由脚本维护。
- 「吃了 X」流程不变；`log` 成功后 `panel` facts 自动更新，无需额外命令。
- 若飞书回复给出下一步饮食建议，必须通过 recommendation writer 写入 `recommendation.json`；不能把 `plan_engine` 或 `panel.suggestions` 作为 fresh 推荐。

## 测试

- `tests/nutrition/test_refresh_panel.py`：log 后 `panel` 存在；remaining 正确；`panel.suggestions == []`；归档无 `panel`。
- 可选 `integration_smoke.check_nutrition_panel`。
