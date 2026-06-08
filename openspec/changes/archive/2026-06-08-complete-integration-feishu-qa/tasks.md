# 实施任务 · complete-integration-feishu-qa

## 1. Hermes 飞书代理脚本

- [x] 1.1 新建 `~/.hermes/scripts/integration_feishu_qa.py`（域 A create+complete 代理链）
- [x] 1.2 域 C「完成 1」隔离 complete + 日历 delete（`HERMES_LEARNING_DATA`）
- [x] 1.3 域 B 30min countdown 契约写入 + 消费校验

## 2. MalDaze 铃铛文案

- [x] 2.1 `SevenMinuteReminderController` 测试钩子 + 单测（completionMessage ≠ 默认分钟文案）
- [x] 2.2 契约 30min + title 由 `integration_feishu_qa` + `InterventionRequestContractTests` 覆盖

## 3. 文档与归档回勾

- [x] 3.1 更新 `MANUAL_QA.md` 飞书话术 ↔ CLI 对照
- [x] 3.2 回勾 `archive/.../tasks-hermes.md` 5.1b、`tasks-maldaze.md` 5.1b
- [x] 3.3 更新 `ROADMAP.md` 脚注；运行 `integration_feishu_qa.py` 全绿
