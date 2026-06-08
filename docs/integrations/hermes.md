# Hermes ↔ MalDaze 集成（canonical）

> **唯一维护处（canonical）**：本文件与 `features/*.md`。  
> Hermes 本地 manifest（伙伴/功能登记表，不复制正文）：  
> `~/.hermes/docs/integrations/README.md` → `~/.hermes/docs/integrations/maldaze.md`

## 关系模型

Hermes = **本机数据/算法后端**（写 JSON、cron、晨报、pmset）  
MalDaze = **前端展示与干预**（读 JSON、铃铛、霸屏、控制面板）

耦合方式：**同机硬编码路径的文件契约**（非 HTTP API、无版本协商）。  
原则：**fail-loud**——契约缺失或字段非法时 MalDaze 停止调度。

**维护规则**：集成相关变更只改本目录 + 双方代码；OpenSpec 归档后把结论合并进来。

**重构总目录**（按项推进）：[ROADMAP.md](./ROADMAP.md) · **联调**：[MANUAL_QA.md](./MANUAL_QA.md)

## 伙伴目录地图

### MalDaze（`~/Public/MalDaze`）

```
MalDaze/
├── MalDaze/SleepReminder/      # 睡眠契约消费者
├── docs/integrations/          # ← canonical（你在这里）
├── openspec/
└── AGENTS.md
```

### Hermes（`~/.hermes`）

```
~/.hermes/
├── docs/integrations/maldaze.md   # 索引，指向本目录
├── scripts/sleep_tracker.py
├── scripts/morning-briefing.py
├── cron/jobs.json
├── data/sleep/sleep_schedule.json
├── data/nutrition/recommend.py
└── tests/sleep/
```

## 集成登记表

| 功能 | 契约 / SSOT | Hermes | MalDaze | 详述 | 状态 |
|------|-------------|--------|---------|------|------|
| 睡眠提醒 | `data/sleep/sleep_schedule.json` | `sleep_tracker.py`, `morning-briefing.py` | `SleepReminder/` | [features/sleep.md](./features/sleep.md) | 已上线 |
| 日待办 | 苹果提醒事项（无跨应用契约） | `day_reminders.py`, day-reminders skill | —（侧栏可选只读） | [features/day-reminders.md](./features/day-reminders.md) | 已上线 |
| 到时强提醒 | `data/maldaze/intervention_request.json` | `intervention_request.py`, desk-intervention skill | `InterventionRequest/` | [features/desk-intervention.md](./features/desk-intervention.md) | 已上线 |
| 学习 SSOT + 飞书完成 | `data/learning-assistant/projects.json` | `schedule.py`, learning skill | — | [learning-calendar.md](./features/learning-calendar.md) | 已上线 |
| 学习桌宠面板 v1 | 同上（经 CLI） | `schedule.py` + `--dry-run` | `LearningDeskPanel/` | [learning-desk-panel.md](./features/learning-desk-panel.md) | 已上线 |
| 学习面板 L3 / rollover | — | l3 / rollover changes | follow-up | [learning-desk-panel-followup.md](./features/learning-desk-panel-followup.md) | 文档就绪 |
| 晨报扩展 | — | `morning-briefing.py` | — | [ROADMAP.md](./ROADMAP.md) §5 | 已上线 |

重构总目录：[ROADMAP.md](./ROADMAP.md) · OpenSpec：`openspec/specs/hermes-*` · `desk-intervention*`（change 已归档 2026-06-08）

## 全局排查

1. 契约文件是否存在、字段齐全  
2. `python3 ~/.hermes/scripts/morning-briefing.py`  
3. MalDaze 控制面板对应状态卡  
4. `rg hermes|sleep_schedule`（MalDaze）；`rg -i maldaze`（Hermes）
