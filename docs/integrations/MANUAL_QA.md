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

## 域 C · 学习 complete（JSON only）

| # | 步骤 | 预期 |
|---|------|------|
| C-1 | `schedule.py today` | `pending` 含 `index` / `task_id` |
| C-2 | 飞书「完成 1」→ `complete --task-id …` | JSON `status: completed`；`daily_log.json` 有记录 |
| C-3 | 响应 JSON | **无** `calendar.action` / `calendar_errors`（学习域已移除飞书日历投影） |

**自动**：`integration_smoke` → `domain_c_complete_roundtrip`；`integration_feishu_qa` → `learning_complete_by_index`（「完成 1」代理）

**ROADMAP**：§10 学习 SSOT → ✅ 已上线 · 日历移除见 `remove-feishu-learning-calendar`

---

## 域 C · 学习桌宠面板（Phase 6 · M-L 完成后启用）

> 设计：[learning-desk-panel.md](./features/learning-desk-panel.md) · ROADMAP §7

| # | 步骤 | 预期 |
|---|------|------|
| M-L-1 | MalDaze 运行，打开 Dashboard | 中栏可见今日任务列表 |
| M-L-2 | 对比 `schedule.py rollover && schedule.py today` | 列表、预算、warnings 与 JSON 一致 |
| M-L-3 | 勾选完成一条 | `projects.json` `status: completed`；行消失 |
| M-L-4 | 「推迟到明天」或改日期 | `move` 级联与飞书同命令一致；有预览确认 |
| M-L-5 | 超额日 | 顶栏以 **小时** 显示当日负荷 vs 设置上限；超额标红 |
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
| M-L3-4 | Week Tab | 文案为 **小时**（非分钟）；默认上限 **5 小时**；超 cap 日标红 |
| M-L3-5 | review 行点失败 | 生成下次复习日期 |
| M-L3-6 | **设置 → 学习面板** 拖动每日上限滑杆 | 今日顶栏 + Week Tab 刷新；`~/.hermes/.../profile.json` 中 `daily_capacity_minutes` = 小时×60 |

**ROADMAP**：§7.2 Phase 6b

---

## 域 C · 学习面板 X7 项目 Tab（`add-learning-project-status`）

| # | 步骤 | 预期 |
|---|------|------|
| M-L8-1 | 切到「项目」Tab | 懒加载 `status`；各项目显示进度、截止日、待办（含时长若有） |
| M-L8-2 | 对比 `schedule.py status` | 字段一致；`next_task` 为 Hermes 队列首条 pending（非按日期排序） |
| M-L8-3 | paused/archived 项目 | 仍列出，视觉弱化；active 排在前面 |
| M-L8-4 | 今日完成一条后切「项目」 | 进度 / 待办已更新，无需手动 ↻ |
| M-L8-5 | 飞书改 `projects.json`（在项目 Tab） | ~1s 内 status 自动刷新；不触发 rollover |
| M-L8-6 | 无 `next_task` 的项目 | 显示「无待办任务」，非错误 |
| M-L8-7 | deadline 已过期 / 7 天内 | 过期与临近分别有明显标色 |
| M-L8-8 | 点项目行或待办 | 切回「今日」并高亮同 `project_id` 首条任务（今日有则滚动） |
| M-L8-9 | 无学习项目（status `[]`） | 空状态文案指向 Hermes 对话发链接 /「帮我安排学习」 |

**ROADMAP**：§7 X7

---

## 域 C · 学习面板 US-10 deadline（`add-learning-project-status` · Hermes `set-deadline`）

| # | 步骤 | 预期 |
|---|------|------|
| M-L9-1 | 点 **「📅 … 修改」** → sheet 选新截止日 → 确认 | 文案说明**会重排未完成课**；确认后 `deadline` 更新 |
| M-L9-2 | 同上操作后看 **今日 / 日程** | 未完成课的 `scheduled_date` 已变；**已完成**课日期不变 |
| M-L9-3 | 终端 `schedule.py set-deadline` 同参数 | 与面板一致；响应含 `changes[]` |
| M-L9-4 | 把截止日改得很紧（可选） | `overflow_count > 0` 时面板有提示 |
| M-L9-5 | paused 项目 | 截止日只读，无按钮 |

**ROADMAP**：§7 X7 · US-10

---

## 域 C · 学习面板日程视图（`add-learning-calendar-view` · 方案 C）

| # | 步骤 | 预期 |
|---|------|------|
| M-L10-1 | 打开学习面板 → **日程** Tab | 上方月历 + 下方按日 Agenda；数据来自 `schedule-range` |
| M-L10-2 | 点月历中某日 | Agenda 滚动到对应日期段并高亮 |
| M-L10-3 | 翻月 ◀ ▶ | 重新加载该月；仍延伸至项目 deadline（若有 overflow 可见 7 月课） |
| M-L10-4 | 有课日 | 显示课名、项目、时长；超容量日标红 |
| M-L10-5 | 截止日 / overflow | 截止日有标记；晚于截止日的课有橙色提示 |
| M-L10-6 | Agenda 行完成 / 推迟 | 与今日 Tab 相同 CLI；成功后日程刷新 |

**ROADMAP**：§7 X8

---

## 域 C · 新建学习项目（`refresh-hermes-project-intake`）

| # | 步骤 | 预期 |
|---|------|------|
| M-L11-1 | 飞书/Hermes 对话发送学习链接 | 摘要 + 任务表；用户确认后直接 `create-project` + `plan`（无 plan dry-run） |
| M-L11-2 | `schedule.py status` | 新项目出现；任务已排期 |
| M-L11-3 | MalDaze 项目 Tab 空状态 / Insert Sheet | 指引「Hermes 对话」；**无**建项目按钮 |
| M-L11-4 | plan overflow | 对话报告 overflow 条数；不要求二次确认建项目 |

**ROADMAP**：`refresh-hermes-project-intake` · `remove-feishu-learning-calendar`

---

## 域 C · 今日 X9/X10（core + navigation）

**完整功能说明、造数、JSON、排障、建议顺序**：[learning-today-x9-x10.md](./features/learning-today-x9-x10.md)

### M-L12-core

| # | 步骤 | 预期 |
|---|------|------|
| M-L12-core-1 | 打开今日 Tab | 正课+复习负荷与预算；超额标红 |
| M-L12-core-2 | 完成 1 节正课 | 完成进度增加；列表刷新 |
| M-L12-core-3 | `auto_roll_days >= 3` | 置顶区；点击滚到主列表行 |
| M-L12-core-4 | 「记录时长并完成」 | Sheet → `--actual-minutes` |
| M-L12-core-5 | 「按项目」分组 | 按 `project_name` 分段 |

### M-L12-nav

| # | 步骤 | 预期 |
|---|------|------|
| M-L12-nav-1 | 超额或落后 | 行动卡各按钮 + 重排须确认 |
| M-L12-nav-2 | 点 warning | 高亮首条 pending 或提示 |
| M-L12-nav-3 | 列表底部 | 明天预告 |
| M-L12-nav-4 | 行内 link | 打开 `source_url` |

**ROADMAP**：§7 X9 · X10

---

## 域 C · rollover（JSON only）

| # | 步骤 | 预期 |
|---|------|------|
| C-R1 | 昨日未完成任务 | `rollover` 后 JSON 日期 = 今天（无日历投影） |

---

## 域 N · 营养今日面板（X2）

详述：[nutrition-today-panel.md](./features/nutrition-today-panel.md)

| # | 步骤 | 预期 |
|---|------|------|
| M-N1 | 打开桌宠 Dashboard | 左栏上计划、下饮食；默认约 60/40 |
| M-N2 | `python3 ~/.hermes/scripts/integration_smoke.py` | `nutrition_panel.ok` 为 true |
| M-N3 | 饮食区 | 日型一行；kcal 条；蛋白/碳水/脂肪/**钠**；已吃只读 |
| M-N4 | 点击建议第一项 | `recommend.py log`；约 1s 内 FSEvents 刷新 |
| M-N5 | 按主键盘 `2`（无修饰） | 与点击第二项等效；文本框聚焦时不触发 |
| M-N6 | 设置 → Dashboard 左栏比例 50% | 重开 Dashboard 计划/饮食约各半 |

**ROADMAP**：§8 X2

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
