## ADDED Requirements

### Requirement: 建议项点击与数字键记录

MalDaze 饮食面板 SHALL 允许用户对 fresh `~/.hermes/data/nutrition/recommendation.json` 快照中 `suggestions[].items[]` 的 `loggable: true` 项执行记录；记录 MUST 调用 Hermes `recommend.py log <name> <grams>`（子进程），且 MUST NOT 直接修改 `daily_log.json` 或 `recommendation.json`。

可记录项 SHALL 按 **扁平序号** 编号：遍历 fresh recommendation `suggestions` 再遍历各 `loggable: true` `items`，从 **1** 开始递增。UI MUST 在序号 ≤9 的项旁显示对应数字前缀。

MalDaze MUST NOT 提供 undo、试算、改训练日/休息日，或对手改 JSON 的等价能力。

MalDaze MUST ignore `daily_log.panel.suggestions` as a recommendation source.

#### Scenario: 点击建议食物项

- **WHEN** 用户点击扁平序号为 N 的 fresh loggable 建议食物行（含 `name` 与 `grams`）
- **THEN** MalDaze 调用 `recommend.py log` 记录该食物与克重
- **AND** 成功后经 FSEvents 刷新展示更新后的 `consumed`、`remaining` 与钠
- **AND** recommendation actions become stale/disabled until Hermes writes a fresh snapshot

#### Scenario: 数字键快捷记录

- **WHEN** Dashboard 可见且无文本输入焦点、无阻塞 Sheet、且存在扁平序号 N（1≤N≤9）的 fresh loggable 可记录项
- **AND** 用户按下主键盘数字键 N（无修饰键）
- **THEN** MalDaze 执行与点击序号 N 相同的 `recommend.py log`
- **AND** 系统吞掉该按键事件以免误输入

#### Scenario: 超过九项

- **WHEN** 可记录项扁平序号大于 9
- **THEN** 第 10 项及以后仅可通过点击记录
- **AND** 数字键 1–9 仍只作用于当前快照中序号 1–9 的项

#### Scenario: 记录进行中互斥

- **WHEN** 已有一次 `log` 子进程尚未结束
- **THEN** MalDaze MUST 忽略额外的点击与数字键直到该次结束

#### Scenario: stale recommendation disables actions

- **WHEN** `daily_log.panel.updatedAt` differs from `recommendation.basedOn.dailyLogPanelUpdatedAt`
- **THEN** MalDaze displays the recommendation as stale
- **AND** click and digit-key logging are disabled

#### Scenario: missing recommendation has no fallback

- **WHEN** `recommendation.json` does not exist
- **THEN** MalDaze displays a waiting/missing recommendation state
- **AND** MalDaze MUST NOT read `daily_log.panel.suggestions`, call `refresh-panel`, call `plan_engine`, or synthesize local recommendations

#### Scenario: 文本输入优先

- **WHEN** Dashboard 内任意文本输入控件持有键盘焦点
- **THEN** 数字键 1–9 MUST NOT 触发饮食记录
- **AND** 按键由输入控件正常处理

#### Scenario: 无其他写入口

- **WHEN** 用户在饮食面板内查找操作
- **THEN** 除建议项点击与数字键记录外无 undo、试算或编辑入口

### Requirement: FSEvents 刷新

MalDaze SHALL 通过 FSEvents 监听 `~/.hermes/data/nutrition/daily_log.json` 与 `~/.hermes/data/nutrition/recommendation.json` 所在目录（文件级事件），在 debounce 约 1 秒后重新加载契约。

#### Scenario: Hermes 更新后刷新

- **WHEN** Hermes 更新 `daily_log.json` 或 `recommendation.json` 且 Dashboard 饮食面板可见
- **THEN** MalDaze 在约 1 秒内刷新展示

#### Scenario: Dashboard 不可见时停止监听

- **WHEN** 用户关闭 Dashboard Panel
- **THEN** MalDaze 停止 FSEvents 监听以降低开销

#### Scenario: 轮询兜底

- **WHEN** Dashboard 打开且 FSEvents 未触发但 `panel.updatedAt` 或 `recommendation.generatedAt` 已变化
- **THEN** MalDaze 在约 45 秒内通过轮询检测到变化并刷新

### Requirement: 日型一行展示

饮食面板 SHALL 在顶区用一行展示 `panel.dayLabel`（训练日或休息日），不展示独立健身视图，且 MUST NOT 读取 `training_log.json`。

#### Scenario: 训练日文案

- **WHEN** `panel.dayLabel` 为「训练日」
- **THEN** 饮食面板顶行显示「训练日」

### Requirement: 宏量钠与建议展示

饮食面板 SHALL 展示：

- `consumed` / `targets` 的热量进度（kcal）
- `consumed` / `remaining` / `targets` 的 **钠 `sodium_mg`** 摘要
- `remaining` 的蛋白、碳水、脂肪简要
- `records` 已吃摘要列表（可滚动；**只读**，不可点击记录）
- `recommendation.json` 建议菜单（可滚动；fresh `loggable: true` items 显示 1–9 序号、可点击、可用数字键记录；stale/missing/unavailable/invalid 时显示明确状态并禁用记录）

#### Scenario: 钠展示

- **WHEN** `panel` 含 `consumed.sodium_mg` 与 `remaining.sodium_mg`
- **THEN** 饮食面板展示钠已摄入与剩余（或等价 consumed/remaining 文案）

#### Scenario: fresh recommendation

- **WHEN** `recommendation.json` is fresh and contains loggable suggestions
- **THEN** 面板展示 summary、标签、rationale、warnings 与分项
- **AND** 每个 `loggable: true` `items[]` 行表现为可点击且序号 ≤9 时显示数字前缀
- **AND** 面板展示「按 1–9 快捷记录」类提示（当存在可记录项且序号 ≤9 时）

#### Scenario: no fresh recommendation

- **WHEN** recommendation is missing, stale, unavailable, invalid, or has no loggable suggestions
- **THEN** 面板仍展示 consumed/remaining（含钠）与已吃列表
- **AND** 显示对应 recommendation 状态
- **AND** 不启用点击或数字键记录

#### Scenario: unavailable recommendation

- **WHEN** `recommendation.json.state` is `unavailable`
- **AND** `summary` contains the user-visible unavailable reason
- **AND** `suggestions` is `[]`
- **THEN** 面板展示 unavailable 状态与 `summary` 文案
- **AND** 面板不启用点击或数字键记录
- **AND** 面板不读取单独 `reason` 字段

### Requirement: 加载与错误态

饮食面板 SHALL 区分加载中、成功、空态（无 panel）、错误（文件缺失、JSON 非法、schema 不支持）、log 失败（CLI 错误文案）。

#### Scenario: 文件缺失

- **WHEN** `daily_log.json` 不存在
- **THEN** 饮食面板显示错误提示与预期路径

#### Scenario: 推荐文件缺失

- **WHEN** `recommendation.json` 不存在但 `daily_log.json` facts 可读
- **THEN** 饮食面板展示 facts
- **AND** 建议区显示等待 Hermes 更新
- **AND** 不本地 fallback

#### Scenario: log 失败

- **WHEN** 用户点击建议项但 `recommend.py log` 返回错误
- **THEN** 饮食面板显示错误提示
- **AND** 不本地修改 JSON
