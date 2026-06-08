# 学习任务与飞书日历（learning-calendar）

Hub：[../hermes.md](../hermes.md) · 总目录：[../ROADMAP.md](../ROADMAP.md)

> **实现主体在 Hermes**（`~/.hermes`）。本文为 canonical 边界说明；skill 细节见 `~/.hermes/skills/learning-assistant/SKILL.md` 与 `references/calendar-setup.md`。

## 职责

| | Hermes | MalDaze |
|---|:------:|:-------:|
| 学习任务 SSOT（`projects.json`） | ✅ | ❌ |
| plan / complete / move / remove | ✅ | ❌ |
| 飞书日历投影（可选） | ✅ | ❌ |
| 飞书对话完成交互 | ✅ | ❌ |
| 桌宠日历 UI | ❌ | ❌ |

## 核心原则（P5）

- **SSOT** = `~/.hermes/data/learning-assistant/projects.json` 内 task `status`
- **飞书日历** = 可选**软投影**，用于扫一周布局；**不是**完成交互本体
- **不**把学习任务迁入苹果提醒事项（丢复习链、容量、move/remove 语义）
- **不**在飞书日历 App 内自定义「完成」按钮（平台不支持）

## 默认日历策略（C0，本 change 定稿）

| 决策 | 选择 | 说明 |
|------|------|------|
| 事件形态 | **全天软锚点** | 仅标记 `scheduled_date` 哪天学，无具体时段 |
| complete 后 | **delete 日历格**（默认） | 飞书日历变干净；**历史仍在本地 JSON**（D6） |
| 完成入口 | **飞书对话** | `schedule.py complete --task-id …`；晨报 today 列表 |

### profile 覆盖项（可选）

`~/.hermes/data/learning-assistant/profile.json`：

```json
{
  "calendar_on_complete": "delete"
}
```

| 值 | complete 后日历行为 |
|----|---------------------|
| `delete`（默认） | lark-cli delete 事件 |
| `checkmark` | patch 标题加 ✅（旧行为） |
| `none` | 不碰日历 |

## 对话完成体验

1. 用户：「今天学完了吗」/「今日学习任务」  
2. Hermes：`schedule.py today` → `pending` 数组（含 `index`、`task_id`）  
3. 用户：「完成 2」或「完成 task_3」  
4. Hermes：`schedule.py complete --task-id task_3` → JSON 保留历史 + 日历 `delete`（默认）

**MalDaze Dashboard** 学习完成/改期见 [learning-desk-panel.md](./learning-desk-panel.md)（展示层 + `schedule.py` CLI，非第二 SSOT）。

## 历史文件（D6 · 删日历 ≠ 删历史）

| 文件 | 作用 |
|------|------|
| `projects.json` | 任务全量含 `status: completed`、`actual_minutes` |
| `daily_log.json` | 按日的 `completed_tasks` |

`complete` 只删飞书日历投影，**禁止** purge 上述文件中的完成记录。

## 与域 A / 域 B 区分

| | 学习（本页） | 日待办 | 到时强提醒 |
|--|-------------|--------|------------|
| SSOT | projects.json | EventKit | intervention JSON |
| 时间语义 | 某天（软） | due date | N 分钟后 |
| 完成 | 飞书 → schedule.py | 飞书 → day_reminders | 点击铃铛消失 |

## 排查

| 现象 | 查什么 |
|------|--------|
| 日历看不到 | `feishu_calendar_id`、`lark-cli` user 身份、非 tenant token |
| complete 后日历还在 | `calendar_on_complete`；是否 delete 失败 stderr |
| 双份事件 | plan 前确认；`search_event` 清孤儿（skill 文档） |

OpenSpec：`openspec/specs/hermes-learning-calendar/spec.md`
