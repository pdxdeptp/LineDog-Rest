## Context

个人助理栈含 **Hermes**（飞书对话、脚本、cron、学习/营养数据）与 **MalDaze**（macOS 强干预 UI）。睡眠集成（`add-sleep-schedule`）已验证模式：Hermes 写 JSON，MalDaze 读并干预。

本 change 将 ROADMAP 三域（A 日待办、B 到时强提醒、C 学习日历）收敛为 OpenSpec + `docs/integrations/features/`。

**运行时耦合总览**：[docs/integrations/hermes.md](../../../docs/integrations/hermes.md)  
**任务总目录**：[docs/integrations/ROADMAP.md](../../../docs/integrations/ROADMAP.md)

| 文档 | 范围 |
|------|------|
| [design-hermes.md](./design-hermes.md) | 域 A/C/D：day-reminders skill、learning 日历策略、晨报扩展、intervention 写端 |
| [design-maldaze.md](./design-maldaze.md) | 域 B：InterventionRequest 消费者、SevenMinute 扩展、legacy SmartInput |

## Goals / Non-Goals

**Goals:**

- 单一对话入口（飞书 Hermes）创建日待办；桌宠不负责写提醒。
- 短生命周期强提醒走薄 JSON 契约 + MalDaze 现有铃铛/倒计时 UI。
- 学习任务完成走 `projects.json` + 飞书对话；日历仅为可选软投影。
- 文档可逐项实施：每个域有 feature 文档 + spec + 分仓 tasks。
- fail-loud：契约非法时 MalDaze 不执行、Hermes 写端报错回飞书。

**Non-Goals:**

- Hermes → MalDaze → EventKit 队列（域 A 明确排除）。
- 学习任务整体迁入苹果提醒事项。
- 桌宠内嵌飞书日历 UI 或完成回写飞书。
- 本 change 删除 SmartReminder 代码或 Gemini 设置（仅 legacy 定位）。
- HTTP API 替代文件契约。

## Decisions

### Decision 1: 三域 SSOT 分离

| 域 | SSOT | 主入口 | MalDaze 角色 |
|----|------|--------|--------------|
| A 日待办 | EventKit Reminders | 飞书 Hermes | 无写端；Dashboard 侧栏可选只读快操 |
| B 强提醒 | `intervention_request.json` | 飞书 Hermes | 读契约 → 倒计时/铃铛 |
| C 学习 | `projects.json` | 飞书 Hermes | 无（可选未来只读卡 ⏸） |

### Decision 2: 分文档记录 Hermes vs MalDaze

与 `add-sleep-schedule` 相同：`design-hermes.md` / `design-maldaze.md`，`tasks-hermes.md` / `tasks-maldaze.md`。`opsx:apply` 默认 MalDaze 任务；Hermes 在 `~/.hermes` 执行。

### Decision 3: 学习日历默认策略（C0 · D6）

- 新事件：**全天软锚点**（无具体时段）。
- `complete` 后：**delete** 飞书日历投影（默认 `calendar_on_complete: delete`）。
- **历史 SSOT**：`projects.json`（含 `status: completed`）+ `daily_log.json` **永久保留**；删日历不等于删历史。
- 完成交互：**飞书对话** + 晨报 today 列表。

### Decision 3b: 用户 scope 拍板（见 scope-decision.md）

| ID | 结论 |
|----|------|
| D1 | 无 intervention 消费回执 |
| D2 | 新 countdown 覆盖旧 Hermes countdown |
| D3 | 不修改 Smart Input 设置/入口 |
| D4 | 单条日待办直接写；批量/重复需确认 |
| D5 | Hermes 提醒列表 = 桌宠 `MalDaze.remindersSelectedCalendarIdentifier`（同 iCloud 列表） |
| D6 | complete 删日历格；JSON 历史文件保留 |
| D7 | 桌宠未运行 → Hermes 拒绝写 intervention 并飞书报错 |

### Decision 4: intervention 单次消费

Hermes 写入 `intervention_request.json`；MalDaze 执行后移至 `intervention_request.consumed.json` 或清空并写 `consumedAt`，避免重复弹。同 `id` 幂等：已消费则忽略。

### Decision 5: Smart Input 不改动（D3）

本 change **不**修改 SmartReminder 入口、设置或快捷键。产品文档将飞书 Hermes 标为主创建路径即可。

## Risks / Trade-offs

- **[Risk] remindctl / osascript 权限** → Hermes skill 文档记录一次性授权；失败 fail-loud 回飞书。
- **[Risk] MalDaze 未运行** → **D7**：Hermes 写 intervention 前检测进程，未运行则飞书 fail-loud，不写契约。
- **[Risk] complete 删日历后用户想回看** → SSOT 在 `projects.json` + `daily_log`；日历非历史档案。
- **[Risk] 动态倒计时与 UserDefaults 7min 冲突** → `start(minutes:message:)` 显式参数优先于设置。

## Migration Plan

1. **文档先行**：features/*.md + 本 OpenSpec change（无代码破坏）。
2. **域 A**：Hermes day-reminders skill 上线 → 晨报段 → 用户迁对话入口。
3. **域 B**：Hermes 写端 + MalDaze 读端联调（煮红薯验收）。
4. **域 C**：`schedule.py` 全天事件 + complete 删事件；更新 skill 对话示例。
5. **Legacy**：MalDaze 设置文案与可选隐藏 Smart Input。

## Open Questions

- 域 A 写入方式最终选型：`remindctl` vs `osascript`（tasks-hermes §1 实施时定稿）。
- `intervention_request` 是否加 `expiresAt`（建议 v1 加，默认 requestedAt + 24h）。
- Dashboard 是否展示「Hermes 倒计时进行中」状态卡（M-B7，可选）。
