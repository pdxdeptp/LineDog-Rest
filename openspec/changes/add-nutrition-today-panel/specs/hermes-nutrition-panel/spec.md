## ADDED Requirements

### Requirement: _refresh_panel 自动维护

Hermes `recommend.py` SHALL 在每次通过 `_update_daily_log` 修改当日数据后调用 `_refresh_panel()`，在同一原子写内更新 `daily_log.json` 的 `panel` 块。

`panel` 的 `consumed`、`remaining`、`targets` SHALL 包含 `sodium_mg`（与现有营养计算一致）。

#### Scenario: log 后刷新

- **WHEN** 用户通过 `recommend.py log` 成功记录一笔食物
- **THEN** `panel.consumed` 与 `panel.remaining` 反映新累计（含钠）
- **AND** `panel.updatedAt` 更新为当前时间
- **AND** `panel.suggestions` 重新生成（可为空数组）

#### Scenario: undo 后刷新

- **WHEN** 用户执行 `recommend.py undo`
- **THEN** `panel` 与撤销后的 `records` 一致

### Requirement: refresh-panel 子命令

Hermes `recommend.py` SHALL 提供 `refresh-panel` 子命令：在不修改 `records` 的前提下重算并写入 `panel`（供晨报、调试、MalDaze 无需 mutating 时的契约修复）。

#### Scenario: 手动 refresh-panel

- **WHEN** 执行 `python3 recommend.py refresh-panel`
- **THEN** `daily_log.json` 的 `panel` 更新且 `records` 不变

### Requirement: integration_smoke panel 契约

`integration_smoke.py` SHALL 包含检查项：读取 `daily_log.json`，断言存在 `panel` 且 `panel.schemaVersion == 1`。

#### Scenario: smoke 全绿

- **WHEN** 执行 `python3 ~/.hermes/scripts/integration_smoke.py`
- **THEN** 营养 panel 检查项 `ok` 为 `true`

### Requirement: 大卡容差 fifty

`_refresh_panel` 生成 `suggestions` 时 SHALL 使用 `plan_engine` 数值优化，且 `panel.calorieSlack` MUST 为 `50`。

每个 suggestion 的 `within_slack` SHALL 为 `true` 当且仅当该建议 `total.kcal` 与刷新时 `remaining.kcal` 之差的绝对值不超过 `calorieSlack`。

#### Scenario: within_slack 标注

- **WHEN** `plan_engine` 产出一条建议且热量差 ≤ 50 kcal
- **THEN** 该条 `within_slack` 为 `true`

### Requirement: v1 单条 Python 基线建议

v1 中 `_refresh_panel` SHALL 通过 `plan_engine` 生成 **至少零条、至多一条** 基线 `suggestions` 项。每个 `items[]` 项 MUST 含 MalDaze 点击 log 所需的 `name`（`foods.json` 键名）与 `grams`（数字）。

#### Scenario: plan_engine 成功

- **WHEN** `plan_engine` 对默认候选食物集优化成功
- **THEN** `panel.suggestions` 长度为 `1`
- **AND** 每项 `items[]` 含 `name` 与 `grams`

#### Scenario: plan_engine 失败

- **WHEN** 无可用食物或优化失败
- **THEN** `panel.suggestions` 为空数组
- **AND** `consumed` / `remaining` 仍正确写入

### Requirement: 晨报刷新 panel

`morning-briefing.py` 在营养 `auto` 与饮食段逻辑完成后 SHALL 刷新当日 `panel`（可调用 `refresh-panel` 或内联 `_refresh_panel`）。

#### Scenario: 晨报后 panel 存在

- **WHEN** 晨报营养段成功执行
- **THEN** `daily_log.json` 含有效 `panel` 且 `panel.schemaVersion == 1`

### Requirement: skill 禁止手改 JSON

`nutrition-menu` skill SHALL 规定：记录与撤销只通过 `recommend.py` 子命令；**禁止**直接编辑 `daily_log.json`。`panel` 由脚本维护；`refresh-panel` 仅供脚本/调试，飞书对话记录仍用 `log`。

#### Scenario: 飞书记录流程

- **WHEN** 用户在飞书说「吃了燕麦 50g」
- **THEN** agent 调用 `recommend.py log`
- **AND** 不得手改 JSON 补 `panel`
