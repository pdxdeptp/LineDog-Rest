## Context

飞书对话本体由 Hermes Agent 解析自然语言后调用既有 CLI（`day_reminders.py`、`schedule.py`、`intervention_request.py`）。本 change **不**改飞书 Bot 或 Agent 代码，而是用 **CLI 代理链** 验证「对话会落到什么命令」且结果正确。

## Decisions

### D1 · 飞书代理 = skill 文档中的 CLI 序列

| 用户话术（示例） | 代理 CLI |
|------------------|----------|
| 「明天超市买奶」 | `day_reminders.py create --title … --due tomorrow` |
| 「完成 1」 | `schedule.py today` → `complete --task-id {pending[0]}` |
| 「煮红薯 30 分钟」 | `intervention_request.py --kind countdown --minutes 30 --title 红薯好了` |

### D2 · 域 C complete 用隔离 `HERMES_LEARNING_DATA`

与 `integration_smoke` `domain_c_complete_roundtrip` 相同，避免修改用户真实 `projects.json`。

### D3 · 30min 目视 = 单测 + 1min smoke

- 单测断言 `completionMessage` 成为铃铛文案。
- smoke 写 `minutes: 1` 快速消费（桌宠运行中）；另写 `minutes: 30` 契约校验字段（不等待 30min）。

### D4 · 报告格式

`integration_feishu_qa.py` 输出 JSON，`ok: true` 当三项均通过；`integration_smoke.py` 可选调用或独立运行。

## Non-Goals

- 真实飞书 WebSocket / Bot API 自动化
- 修改 Hermes Agent prompt 或 skill 正文
