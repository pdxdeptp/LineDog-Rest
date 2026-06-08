## Context

Hermes（`~/.hermes`）是个人 agent 后端：飞书通道、cron、学习助手 `schedule.py`、晨报 `morning-briefing.py`。本 change 扩展三个写端域，**不**实现 macOS UI。

索引：[~/.hermes/docs/integrations/README.md](file:///Users/cpt/.hermes/docs/integrations/README.md)  
Canonical：[docs/integrations/hermes.md](../../../docs/integrations/hermes.md)

## Goals / Non-Goals

**Goals:**

- 域 A：飞书对话端到端写苹果提醒事项。
- 域 B：飞书对话写 `intervention_request.json`。
- 域 C：学习日历软投影 + complete 删事件 + 对话完成体验。
- 域 D：晨报聚合今日提醒与学习任务。

**Non-Goals:**

- MalDaze EventKit 协作队列。
- 桌宠窗口 / 铃铛实现。
- 修改睡眠契约算法（`sleep_tracker.py` 行为不变）。

## Decisions

### H1: day-reminders skill 结构

```
~/.hermes/skills/day-reminders/
├── SKILL.md
└── references/
    ├── eventkit-write.md    # remindctl / osascript 选型与权限
    └── dialogue-examples.md
```

对话能力：create、list-today、complete、postpone、delete。自然语言由 Hermes agent 解析为结构化参数后调脚本（建议 `scripts/day_reminders.py` CLI，供 skill 与晨报复用）。

**创建确认（D4）**：单条直接写入；批量创建或含重复规则时须先预览并得用户确认后再写。

**提醒列表（D5）**：写入目标列表与桌宠 Dashboard 一致——读取 macOS UserDefaults：

```bash
defaults read com.maldaze.MalDaze MalDaze.remindersSelectedCalendarIdentifier 2>/dev/null
```

- 有值 → 用该 `calendarIdentifier` 写入（与手机 iCloud 同步列表一致，前提是桌宠已选过该列表）。
- 无值 → 与 `RemindersDefaultListResolver` 同逻辑：优先标题「提醒事项」/ `Reminders`，否则第一张可写列表。
- 可选：桌宠首次 `prepare()` 后即有选定列表；Hermes 文档说明「在桌宠 Dashboard 选一次列表后 Hermes 与侧栏对齐」。

### H2: EventKit 写入方式（实施时 A1 定稿）

| 方式 | 优点 | 缺点 |
|------|------|------|
| `remindctl` | 稳定 CLI | 需安装 |
| `osascript` | 系统自带 | 错误信息弱 |
| Shortcuts | 用户可见 | 难自动化测试 |

**默认倾向**：`remindctl`；无则文档 fallback `osascript`。

### H3: intervention 写端

- 路径：`~/.hermes/data/maldaze/intervention_request.json`
- 模块：`scripts/intervention_request.py` 或 skill `skills/desk-intervention/`
- **写前门禁（D7）**：检测 MalDaze 进程运行（如 `pgrep -x MalDaze` 或 `pgrep -f MalDaze.app`）。**未运行则拒绝写入**，stderr/stdout JSON 错误 + 飞书明确文案：「MalDaze 桌宠未运行，请先打开桌宠再设置强提醒。」
- 写前：确保 `data/maldaze/` 存在；校验 schema；`expiresAt` 默认 `requestedAt + 24h`
- 时长推断：显式分钟 > 用户 profile 默认 > 常识表（红薯等可扩展 `data/maldaze/defaults.json`）
- **并发（D2）**：新 countdown 直接覆盖 pending 文件；若 MalDaze 已在跑旧 Hermes 倒计时，由 MalDaze 消费新契约时覆盖（见 design-maldaze）
- **无消费回执（D1）**：写成功即回复用户；不轮询 `consumed/`

### H4: 学习日历策略（默认）

`schedule.py` `calendar_create_event`：

- 使用**全天事件**（`start_date` 仅日期，`is_all_day: true` 或 lark-cli 等价字段）
- 标题：`{项目名} · {任务标题}`（无具体时段）

`cmd_complete` 日历处理（`profile.calendar_on_complete`，默认 `delete`）：

| 值 | 行为 |
|----|------|
| `delete`（默认 · D6） | lark-cli delete 事件，清空 `feishu_event_id`；**不**删除 `projects.json` / `daily_log.json` 中已完成记录 |
| `checkmark` | patch summary 加 ✅ |
| `none` | 不动日历 |

**历史文件（D6）**：日历格消失后，查询/复盘走 `projects.json`（task `status`、`actual_minutes`）与 `daily_log.json`（`completed_tasks`）。禁止 `complete` 时 purge 任务历史。

### H5: 晨报扩展

`morning-briefing.py` 新增段落（在既有睡眠/营养之间或之后）：

1. **📋 今日提醒**：调 `day_reminders.py list-today` 或内联查询
2. **📚 今日学习**：调 `schedule.py today --json` pending 列表

排版：全角分隔 / 逐行 key-value；**禁止 markdown 表格**。

### H6: manifest 维护

每上线一域，在 `~/.hermes/docs/integrations/README.md` 功能表加一行，链到 MalDaze `docs/integrations/features/*.md`。

## Risks / Trade-offs

- **[Risk] lark-cli patch 拼写** → 继续只用 `patch` 子命令（MEMORY 已有）。
- **[Risk] delete 日历后飞书通知缓存** → 用户刷新日历；任务状态以 `projects.json` 为准。

## Open Questions

- `day_reminders.py` 是否独立脚本还是并入现有 `schedule.py`（建议独立，域 A 与 C 解耦）。
