## ADDED Requirements

### Requirement: 契约文件路径与所有权

系统 SHALL 使用 `~/.hermes/data/nutrition/daily_log.json` 作为 Hermes 与 MalDaze 之间的营养今日契约载体。

Hermes SHALL 通过 `recommend.py` 独占写入 `daily_log.json`（含 `records` 与派生 `panel`）。MalDaze SHALL 只读 JSON 文件本体，写操作 MUST 仅通过调用 `recommend.py log` 等子进程完成。

#### Scenario: Hermes 写入

- **WHEN** Hermes `recommend.py` 成功执行 mutating 子命令或 `refresh-panel`
- **THEN** Hermes 原子更新 `daily_log.json`
- **AND** 同一写入包含最新的 `panel` 块

#### Scenario: MalDaze 读取

- **WHEN** MalDaze 饮食面板需要展示
- **THEN** MalDaze 从上述路径读取 JSON
- **AND** MalDaze MUST NOT 直接写入该文件

#### Scenario: MalDaze 点击记录

- **WHEN** 用户在 MalDaze 点击建议食物项
- **THEN** MalDaze 调用 `recommend.py log` 而非改写 JSON

### Requirement: panel 必填字段

`daily_log.json` 的 `panel` 对象（当存在且 MalDaze 展示饮食面板时）SHALL 包含：

- `schemaVersion`（整数，当前为 `1`）
- `updatedAt`（ISO 8601，含时区）
- `dayLabel`（字符串，如「训练日」「休息日」）
- `targets`、`consumed`、`remaining`（各含 `kcal`、`protein_g`、`carbs_g`、`fat_g`、`sodium_mg`）
- `suggestions`（数组，可为空）
- `calorieSlack`（整数，当前为 `50`）

每个 `suggestions[]` 项 SHALL 含 `label`、`items[]`（`name`、`grams`、营养素）、`total`（营养素汇总）、`within_slack`（布尔）。

#### Scenario: 完整 panel

- **WHEN** MalDaze 读取到 `panel.schemaVersion == 1` 且上述字段齐全
- **THEN** MalDaze 渲染饮食面板（含钠）

#### Scenario: 缺 panel

- **WHEN** `daily_log.json` 存在但无 `panel` 键
- **THEN** MalDaze MUST 显示空态
- **AND** MalDaze MUST NOT 调用 Hermes 脚本补算（用户或晨报应跑 `refresh-panel`）

#### Scenario: 不支持的 schemaVersion

- **WHEN** `panel.schemaVersion` 存在且不等于 `1`
- **THEN** MalDaze MUST 显示错误态

### Requirement: 历史归档不含 panel

Hermes 将过期 `daily_log` 归档至 `history/YYYY-MM-DD.json` 时 SHALL 只保留 `date`、`day_type`、`records`、`weight_kg`（及历史已有字段），且 MUST NOT 写入 `panel`。

#### Scenario: 日切归档

- **WHEN** Hermes 检测到 `daily_log.date` 早于今日并归档
- **THEN** `history/` 文件中无 `panel` 键

### Requirement: records 与 day_type

MalDaze 饮食面板 SHALL 读取顶层 `date` 与 `records[]` 以展示「已吃」列表。日型展示文案 MUST 使用 `panel.dayLabel`。

#### Scenario: 已吃列表

- **WHEN** `records` 非空
- **THEN** MalDaze 在饮食面板展示各笔记录的名称与热量摘要（只读）
