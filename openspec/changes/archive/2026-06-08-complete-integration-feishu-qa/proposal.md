## Why

`unify-personal-assistant` 归档时三项飞书/目视联调（tasks-hermes 5.1b、tasks-maldaze 5.1b、学习「完成 N」）仍为可选手工，缺少可重复运行的验收脚本与单测兜底。需要补齐自动化代理路径，使 opsx 可勾选关闭。

总目录：[docs/integrations/ROADMAP.md](../../../docs/integrations/ROADMAP.md)

## What Changes

- 新增 `~/.hermes/scripts/integration_feishu_qa.py`：模拟飞书 Hermes 对话触发的 CLI 链（域 A 创建日待办、域 C 编号完成）。
- 扩展 `integration_smoke.py` 或并入 feishu_qa：30min countdown 契约消费 + 标题字段校验。
- MalDaze 单测：`SevenMinuteReminderController` 倒计时结束铃铛文案 = `completionMessage`（非「X 分钟计时结束」）。
- 更新 `MANUAL_QA.md` 飞书话术对照；回勾归档 change 中 5.1b 任务。

## Capabilities

### New Capabilities

- `integration-feishu-qa`: 飞书对话代理验收脚本与报告格式（stdout JSON）。

### Modified Capabilities

- （无）行为已在 `hermes-day-reminders`、`hermes-learning-calendar`、`desk-intervention` 主 spec 中定义；本 change 仅补验收。

## Impact

- **Hermes**：`scripts/integration_feishu_qa.py`、可选 `integration_smoke.py` 扩展
- **MalDaze**：`SevenMinuteReminderController` 测试钩子 + 单测
- **文档**：`MANUAL_QA.md`、`ROADMAP.md` 脚注；归档 tasks 5.1b 勾选
