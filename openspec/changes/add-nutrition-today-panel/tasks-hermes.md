# Hermes · nutrition panel

> 路径：`~/.hermes/data/nutrition/` · skill：`skills/nutrition/nutrition-menu/`

## 1. `_refresh_panel`

- [x] 1.1 实现 `_refresh_panel(daily_log)`：targets/consumed/remaining/dayLabel/calorieSlack（含 **sodium_mg**）
- [x] 1.2 `_build_panel_suggestions`：plan_engine **脚本内常量食物集（S1）** → 0–1 条；`items[]` 含 **name + grams**
- [x] 1.3 挂钩 `_update_daily_log` 所有 mutating 路径
- [x] 1.4 归档 `history/` 剥离 `panel`

## 2. refresh-panel & 晨报

- [x] 2.1 **`recommend.py refresh-panel` 子命令（S4）**
- [x] 2.2 `morning-briefing.py` 营养段后 `refresh-panel` 或内联 `_refresh_panel`

## 3. integration_smoke（S3）

- [x] 3.1 `integration_smoke.py` → `check_nutrition_panel`：`panel.schemaVersion == 1`
- [x] 3.2 smoke 汇总 `ok` 纳入营养项

## 4. Skill & 文档

- [x] 4.1 `nutrition-menu/SKILL.md`：禁止手改 daily_log；`refresh-panel` 仅调试/脚本
- [x] 4.2 integrations / `data/nutrition/README`：`panel` 字段（含钠、可点击 items）

## 5. 测试

- [x] 5.1 `tests/nutrition/test_refresh_panel.py`（log → panel 含钠；items name/grams；归档无 panel）
- [x] 5.2 `tests/nutrition/test_refresh_panel_cmd.py`（refresh-panel 不改 records）

## 6. 验收

- [x] 6.1 `integration_smoke.py` 营养项绿
- [x] 6.2 `openspec validate add-nutrition-today-panel --strict`
