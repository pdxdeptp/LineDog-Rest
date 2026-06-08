## Why

飞书 + Hermes 已成为日常对话入口，但日待办、到时强提醒、学习任务与桌宠能力边界混杂：SmartReminder 重复 Hermes 的 NLP 能力，飞书日历事件缺少「完成」交互，煮红薯类短计时又需要桌宠级强感知。需要一次架构收敛，把三域分工写进可归档的 OpenSpec 与 `docs/integrations/features/`，再按任务 ID 逐项实现。

总目录（任务 ID、Phase）：[docs/integrations/ROADMAP.md](../../../docs/integrations/ROADMAP.md)

## What Changes

### 域 A · 日待办（Hermes 端到端，桌宠不参与写链路）

- 新建 Hermes skill：自然语言 → 苹果「提醒事项」（创建 / 列出今日 / 完成 / 推迟）。
- 晨报 `morning-briefing.py` 增加今日提醒摘要段。
- **不**新增 Hermes → MalDaze → EventKit 协作队列。

### 域 B · 到时强提醒（Hermes 写契约 → MalDaze 弹出）

- 新建 `~/.hermes/data/maldaze/intervention_request.json` 契约（`countdown` / `bell` / `cancel`）。
- Hermes skill：飞书对话推断时长并写契约。
- MalDaze 新建 `InterventionRequest/` 消费者：FSEvents、动态倒计时、中央铃铛、消费 ack。
- 扩展 `SevenMinuteReminderController` 支持 Hermes 指定的动态分钟数。

### 域 C · 学习任务与飞书日历（Hermes only）

- 明确 SSOT = `projects.json`；飞书日历降为**全天软锚点**可选投影。
- `complete` 后默认 **delete** 飞书事件（减少日历噪音；见 design-hermes 可覆盖）。
- 强化飞书对话完成体验（`today` + 编号完成）；**不**迁到苹果提醒事项。
- 参考文档：`docs/integrations/features/learning-calendar.md`（canonical 旁注链 Hermes skill references）。

### 域 D · 晨报聚合（Hermes）

- 晨报合并：今日苹果提醒 + 今日 pending 学习任务 + 既有睡眠/营养段。
- 飞书排版遵守无 markdown 表格规则。

### MalDaze（本 change 不改动 Smart Input）

- **SmartReminder 保持现状**：不增加隐藏入口设置，不改右键/快捷键/设置 UI（scope-decision D3）。
- Dashboard「计划」侧栏**保留**为 EventKit 只读快操；Hermes 创建提醒写入**同一列表**（D5）。
- 文档仍将飞书 Hermes 标为主创建路径；代码层不削 Smart Input。

### 文档

- `docs/integrations/features/day-reminders.md`
- `docs/integrations/features/desk-intervention.md`
- `docs/integrations/features/learning-calendar.md`
- 更新 `docs/integrations/hermes.md` 集成登记表

## Capabilities

### New Capabilities

- `desk-intervention`: MalDaze 读取并执行 Hermes 发起的到时强提醒（倒计时 / 即时铃铛 / 取消）。
- `desk-intervention-contract`: `intervention_request.json` 路径、schema、写读所有权、消费语义。
- `hermes-day-reminders`: Hermes 端到端管理苹果提醒事项（skill、权限、对话指令）；桌宠无写端。
- `hermes-learning-calendar`: 学习任务日历投影策略、complete 后处理、对话完成体验（实现于 `~/.hermes`，本 change 文档化）。
- `hermes-morning-briefing`: 晨报扩展段（今日提醒 + 今日学习任务）；与既有睡眠段并列。

### Modified Capabilities

- （无）`desk-pet-controls` 本 change **不修改** spec（Smart Input 保持现状，见 [scope-decision.md](./scope-decision.md) D3）。

## Impact

- **Hermes**（`~/.hermes`）：新 skills、`scripts/morning-briefing.py`、`scripts/schedule.py` 日历策略、`data/maldaze/` 契约目录。
- **MalDaze Swift**：新建 `InterventionRequest/`；扩展 `SevenMinuteReminderController`；`AppViewModel` 接线（**不**改 Smart Input，D3）。
- **文档**：`docs/integrations/` canonical + OpenSpec change；Hermes manifest 索引行。
- **不改动**：睡眠契约（`add-sleep-schedule` 已上线）、番茄/整点休息引擎、学习助手 `projects.json` SSOT 模型本身。

## Affected Specs

- `desk-intervention`（新建）
- `desk-intervention-contract`（新建）
- `hermes-day-reminders`（新建）
- `hermes-learning-calendar`（新建）
- `hermes-morning-briefing`（新建）
