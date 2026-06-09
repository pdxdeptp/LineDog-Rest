## ADDED Requirements

### Requirement: 建议项点击与数字键记录

MalDaze 饮食面板 SHALL 允许用户对当前 `panel` 快照中 `suggestions[].items[]` 的每一项执行记录；记录 MUST 调用 Hermes `recommend.py log <name> <grams>`（子进程），且 MUST NOT 直接修改 `daily_log.json`。

可记录项 SHALL 按 **扁平序号** 编号：遍历 `suggestions` 再遍历各 `items`，从 **1** 开始递增。UI MUST 在序号 ≤9 的项旁显示对应数字前缀。

MalDaze MUST NOT 提供 undo、试算、改训练日/休息日，或对手改 JSON 的等价能力。

#### Scenario: 点击建议食物项

- **WHEN** 用户点击扁平序号为 N 的建议食物行（含 `name` 与 `grams`）
- **THEN** MalDaze 调用 `recommend.py log` 记录该食物与克重
- **AND** 成功后经 FSEvents 刷新展示更新后的 `consumed`、`remaining`、`suggestions` 与钠

#### Scenario: 数字键快捷记录

- **WHEN** Dashboard 可见且无文本输入焦点、无阻塞 Sheet、且存在扁平序号 N（1≤N≤9）的可记录项
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

#### Scenario: 文本输入优先

- **WHEN** Dashboard 内任意文本输入控件持有键盘焦点
- **THEN** 数字键 1–9 MUST NOT 触发饮食记录
- **AND** 按键由输入控件正常处理

#### Scenario: 无其他写入口

- **WHEN** 用户在饮食面板内查找操作
- **THEN** 除建议项点击与数字键记录外无 undo、试算或编辑入口

### Requirement: FSEvents 刷新

MalDaze SHALL 通过 FSEvents 监听 `~/.hermes/data/nutrition/daily_log.json` 所在目录（文件级事件），在 debounce 约 1 秒后重新加载契约。

#### Scenario: Hermes 更新后刷新

- **WHEN** Hermes 更新 `daily_log.json` 且 Dashboard 饮食面板可见
- **THEN** MalDaze 在约 1 秒内刷新展示

#### Scenario: Dashboard 不可见时停止监听

- **WHEN** 用户关闭 Dashboard Panel
- **THEN** MalDaze 停止 FSEvents 监听以降低开销

#### Scenario: 轮询兜底

- **WHEN** Dashboard 打开且 FSEvents 未触发但 `panel.updatedAt` 已变化
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
- `panel.suggestions` 建议菜单（可滚动；**items 显示 1–9 序号、可点击、可用数字键记录**；空时显示「暂无建议」）

#### Scenario: 钠展示

- **WHEN** `panel` 含 `consumed.sodium_mg` 与 `remaining.sodium_mg`
- **THEN** 饮食面板展示钠已摄入与剩余（或等价 consumed/remaining 文案）

#### Scenario: 有建议

- **WHEN** `suggestions` 非空
- **THEN** 面板展示标签、分项克重与 `total.kcal`
- **AND** 每个 `items[]` 行表现为可点击且序号 ≤9 时显示数字前缀
- **AND** 面板展示「按 1–9 快捷记录」类提示（当存在可记录项且序号 ≤9 时）
- **AND** 当 `within_slack` 为 true 时标示在 ±50 kcal 容差内

#### Scenario: 无建议

- **WHEN** `suggestions` 为空
- **THEN** 面板仍展示 consumed/remaining（含钠）与已吃列表
- **AND** 显示「暂无建议」

### Requirement: 加载与错误态

饮食面板 SHALL 区分加载中、成功、空态（无 panel）、错误（文件缺失、JSON 非法、schema 不支持）、log 失败（CLI 错误文案）。

#### Scenario: 文件缺失

- **WHEN** `daily_log.json` 不存在
- **THEN** 饮食面板显示错误提示与预期路径

#### Scenario: log 失败

- **WHEN** 用户点击建议项但 `recommend.py log` 返回错误
- **THEN** 饮食面板显示错误提示
- **AND** 不本地修改 JSON
