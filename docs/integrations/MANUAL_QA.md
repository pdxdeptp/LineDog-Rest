# 联调验收手册（Hermes ↔ MalDaze）

> 对照 [ROADMAP.md](./ROADMAP.md) §10 登记表；代码就绪后按序手工验收。  
> 自动冒烟：`python3 ~/.hermes/scripts/integration_smoke.py`

## 0. 通用准备

```bash
cd ~/Public/MalDaze && xcodebuild -scheme MalDaze -destination 'platform=macOS' build
cd ~/.hermes && python3 scripts/integration_smoke.py
cd ~/Public/MalDaze && xcodebuild test -scheme MalDaze -destination 'platform=macOS' \
  -only-testing:MalDazeTests/SleepScheduleContractTests \
  -only-testing:MalDazeTests/SleepReminderClamshellTests \
  -only-testing:MalDazeTests/InterventionRequestContractTests
```

---

## 域 D · 睡眠提醒（add-sleep-schedule）

| # | 步骤 | 预期 |
|---|------|------|
| D-S1 | `integration_smoke` → `sleep_schedule_contract` / `sleep_tracker_tests` / `sleep_updated_at_roundtrip` | 均为 `ok: true` |
| D-S2 | 合盖取消 | `SleepReminderClamshellTests` 通过；或合盖时睡眠霸屏消失 |
| D-S3 | 一晚目视（可选） | 合盖 → 次日 08:00 晨报 🌙 → 当晚 T-60/T-30/deadline/霸屏时刻正确 |

**自动**：`integration_smoke` sleep_* 项。**ROADMAP**：§10 睡眠提醒 → ✅

---

## 飞书对话代理验收（一键）

```bash
python3 ~/.hermes/scripts/integration_feishu_qa.py
```

| 飞书话术（示例） | Hermes 实际执行的 CLI 链 | 报告字段 |
|------------------|-------------------------|----------|
| 「明天超市买奶」 | `day_reminders.py create --title … --due today` → `complete --query` | `day_reminder_feishu_proxy` |
| 「完成 1」 | `schedule.py today` → `complete --task-id {pending[0]}` | `learning_complete_by_index` |
| 「煮红薯 30 分钟」 | cron `30m` → 到点 `intervention_request.py --kind bell --title 红薯煮好了` | `bell_cooking_reminder` |

> 代理脚本验证 CLI 链路与桌宠消费；真实飞书 NL 解析仍走 Hermes Agent，行为应与上表一致。

---

## 域 A · 日待办

| # | 步骤 | 预期 |
|---|------|------|
| A-1 | `remindctl authorize`（运行 Hermes 的终端 App） | 系统设置 → 隐私与安全性 → **提醒事项** → 允许 **Terminal**（或 iTerm）；`remindctl status --json` → `authorized: true` |
| A-2 | `python3 ~/.hermes/scripts/day_reminders.py resolve-list` | `ok: true`，列表与桌宠 Dashboard 一致 |
| A-3 | `integration_feishu_qa` → `day_reminder_feishu_proxy` | `ok: true`（tasks-hermes 5.1b） |
| A-3 | `create --title "联调-银行" --due tomorrow` | 提醒事项 App 可见 |
| A-4 | `list-today` / `complete --query "联调"` | 完成成功 |

**ROADMAP**：§10 日待办 → 已上线

---

## 域 B · 到时强提醒（cron + bell）

| # | 步骤 | 预期 |
|---|------|------|
| B-1 | MalDaze **运行中**（到点写 bell 前） | `pgrep -x MalDaze`；`integration_smoke.py` → `intervention_consume.ok: true` |
| B-2 | 飞书：「提醒我 1 分钟后联调红薯」 | Hermes **cronjob create**（非创建时 countdown） |
| B-3 | 等待期 | **无**桌宠右下角倒计时（预期） |
| B-4 | 到点 | Agent 执行 `intervention_request.py --kind bell --title "联调-红薯"` |
| B-5 | 观察桌宠 | 中央铃铛文案 **联调-红薯** |
| B-6 | 同 `id` 再写 bell | 不二次弹（幂等） |
| B-7 | 桌宠未开时到点写 bell | 脚本报错，不写 JSON（D7） |
| B-8 | 取消 | `hermes cron list` → `remove <job_id>` |

**自动**：`integration_feishu_qa` → `bell_cooking_reminder`；`SevenMinuteReminderCompletionTests`（铃铛文案 = title）

**ROADMAP**：§10 到时强提醒 → 已上线

---

## 域 C · 学习 complete + 日历

| # | 步骤 | 预期 |
|---|------|------|
| C-1 | `schedule.py today` | `pending` 含 `index` / `task_id` |
| C-2 | 飞书「完成 1」→ `complete --task-id …` | JSON `status: completed`；`calendar.action: delete` |
| C-3 | 飞书日历 | 对应全天格 **消失**；`projects.json` 历史仍在 |

**自动**：`integration_smoke` → `domain_c_complete_roundtrip`；`integration_feishu_qa` → `learning_complete_by_index`（「完成 1」代理）

**ROADMAP**：§10 学习 SSOT → ✅ 已上线

---

## 域 C · 学习桌宠面板（Phase 6 · M-L 完成后启用）

> 设计：[learning-desk-panel.md](./features/learning-desk-panel.md) · ROADMAP §7

| # | 步骤 | 预期 |
|---|------|------|
| M-L-1 | MalDaze 运行，打开 Dashboard | 中栏可见今日任务列表 |
| M-L-2 | 对比 `schedule.py rollover && schedule.py today` | 列表、预算、warnings 与 JSON 一致 |
| M-L-3 | 勾选完成一条 | `projects.json` `status: completed`；行消失 |
| M-L-4 | 「推迟到明天」或改日期 | `move` 级联与飞书同命令一致；有预览确认 |
| M-L-5 | 超额日 | 顶栏 `total_minutes > budget` 标红 |
| M-L-6 | `auto_roll_days ≥ 1` | 行内「已滚 N 天」角标 |
| M-L-7 | 左栏提醒、右栏桌宠 | 无布局/功能回归 |

**自动**：`integration_smoke` 域 C 项仍应全绿（面板不改变 Hermes 契约）。

**ROADMAP**：§7.1 Phase 6a v1 → 验收后改 🟡→✅

---

## 域 C · 学习面板 L3（Phase 6b · v1 后 · 文档：`add-learning-desk-panel-l3`）

| # | 步骤 | 预期 |
|---|------|------|
| M-L3-1 | insert 一条任务 | today 可见；JSON 有 pending |
| M-L3-2 | remove 确认删 | 行消失 |
| M-L3-3 | 飞书改计划后（projects.json 变更） | 1s 内面板自动刷新 |
| M-L3-4 | Week Tab | 超 cap 日标红 |
| M-L3-5 | review 行点失败 | 生成下次复习日期 |

**ROADMAP**：§7.2 Phase 6b

---

## 域 C · rollover 日历（Phase 6c · `fix-learning-rollover-calendar`）

| # | 步骤 | 预期 |
|---|------|------|
| C-R1 | 昨日未完成任务 | `rollover` 后 JSON 日期 = 今天 |
| C-R2 | 同上任务有 `feishu_event_id` | 飞书全天格日期与 JSON 一致 |

**ROADMAP**：§7.3 Phase 6c

---

## 域 F · 晨报

| # | 步骤 | 预期 |
|---|------|------|
| D-1 | `python3 ~/.hermes/scripts/morning-briefing.py` | 含 📋 📚 🌙 段（📋 需 remindctl 或 osascript 回退） |
| D-2 | `cron/jobs.json` | `0 8 * * *` enabled |

**ROADMAP**：§10 晨报 → 已上线

---

## 全部通过后

1. 更新 [ROADMAP.md](./ROADMAP.md) §10 各行 → **已上线**
2. 更新 [hermes.md](./hermes.md) 登记表
3. 更新 `~/.hermes/docs/integrations/README.md`
4. 勾选 `tasks-hermes.md` §5、`tasks-maldaze.md` §5
5. ~~`openspec archive unify-personal-assistant`~~ → **已完成**（2026-06-08 → `archive/2026-06-08-unify-personal-assistant`）
