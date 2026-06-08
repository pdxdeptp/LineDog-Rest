# Hermes 实施任务（`~/.hermes`）

> 在 MalDaze 域 B 读端联调前，至少完成 §1 或 §4 写端之一以便验收。  
> 任务 ID 与 [ROADMAP.md](../../../docs/integrations/ROADMAP.md) 对齐。

## 1. 域 A · 日待办（A1–A6）

- [x] 1.1 **A1** 选型 `remindctl` + 文档化；**D5** 读 `defaults read com.maldaze.MalDaze MalDaze.remindersSelectedCalendarIdentifier` + fallback
- [x] 1.1b **D4** skill 写明：单条直接写；批量/重复须确认
- [x] 1.2 **A2** 新建 `skills/day-reminders/SKILL.md` + `scripts/day_reminders.py` CLI（create / list-today / complete / postpone / delete）
- [x] 1.3 **A3** 飞书对话示例与结构化参数映射 → `references/dialogue-examples.md`
- [x] 1.4 **A4** 完成 / 推迟 / 删除对话路径冒烟（CLI 就绪；飞书端到端待 authorize）
- [x] 1.5 **A5** `tests/day-reminders/` 8 passed
- [x] 1.6 更新 `~/.hermes/docs/integrations/README.md` 域 A 表行 → 链 `features/day-reminders.md`

## 2. 域 C · 学习日历（C0–C5）

- [x] 2.1 **C0** `profile.calendar_on_complete: delete` 已写入 profile.json
- [x] 2.2 **C1** `calendar_create_event` 全天 date-only 软锚点
- [x] 2.3 **C2/D6** `apply_calendar_on_complete`；complete/review/calendar-sync 支持 delete/checkmark/none
- [x] 2.4 **C3** `today` 输出 `pending` 扁平列表 + `pending_count`
- [x] 2.5 **C4** `learning-assistant/SKILL.md` §2–3 编号完成流程
- [x] 2.6 **C5** `references/calendar-orphan-cleanup.md`

## 3. 域 D · 晨报（F1–F5）

- [x] 3.1 **F1** `morning-briefing.py` 📋 段（`day_reminders.py list-today`）
- [x] 3.2 **F2** 📚 段改用 `schedule.py today` pending
- [x] 3.3 **F3/F4** 睡眠段保留；全 `·` 行排版无表格
- [x] 3.4 **F5** `cron/jobs.json` `0 8 * * *` enabled（id 11778f4fdbcb）

## 4. 域 B · 强提醒写端（B1–B4）

- [x] 4.1 创建 `data/maldaze/` 目录与 README 链回 canonical
- [x] 4.2 **B1/D7** `intervention_request.py`：写前 `pgrep` MalDaze；未运行 → 非零退出 + 飞书报错文案
- [x] 4.2b **D2** 新写覆盖 pending；**D1** 无消费回执
- [x] 4.3 **B2** 时长推断 + 可选 `data/maldaze/defaults.json`
- [x] 4.4 **B3** 写失败 JSON + 非零退出码
- [x] 4.5 **B4** `kind: cancel` 写端
- [x] 4.6 更新 manifest 域 B 表行 → 链 `features/desk-intervention.md`（待手工联调）

## 5. 联调

- [x] 5.1a CLI roundtrip（`integration_smoke` day_reminders_roundtrip；remindctl full-access）
- [x] 5.1b 飞书创建日待办 → `integration_feishu_qa` `day_reminder_feishu_proxy`
- [x] 5.2 域 B 自动冒烟（consume / idempotent / invalid JSON）
- [x] 5.3 域 C complete + 日历 delete（`integration_smoke` domain_c_complete_roundtrip；`schedule.py` `HERMES_HOME` + `--as user`）
- [x] 5.4 晨报四段齐全（`integration_smoke` morning_briefing_sections + 📋 内容）
