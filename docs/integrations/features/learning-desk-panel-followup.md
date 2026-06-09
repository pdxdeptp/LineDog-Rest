# 学习桌宠面板 · 延后工作索引（follow-up）

Hub：[learning-desk-panel.md](./learning-desk-panel.md) · 总目录：[../ROADMAP.md](../ROADMAP.md) §7

> **状态**：L3 **MANUAL_QA 通过**（2026-06-08）· **未归档** · **前置**：v1 已归档

scope-decision **A** 将面板拆成三档交付；本文汇总 **v1 之后**全部已写清的 OpenSpec 与任务，避免 apply v1 时 scope drift。

---

## 交付分档

| 档位 | OpenSpec change | 内容 | 阻塞关系 |
|------|-----------------|------|----------|
| **v1** | `archive/2026-06-08-add-learning-desk-panel` | 三栏、Today、complete、move+dry-run | ✅ |
| **v1.1 面板增强** | `add-learning-desk-panel-l3` | insert/remove、Week（小时）、FSEvents、review、每日上限设置 | ✅ QA 通过 · 未归档 |
| **X7 · 项目 Tab** | `add-learning-project-status` | `status` 总览 + 面板 `set-deadline`（US-10） | L3 QA 通过后 |

---

## X7 · 项目 Tab + deadline（`add-learning-project-status`）

### 用户价值

| 能力 | v2 对应 | 说明 |
|------|---------|------|
| 项目总览 | US-12 | 第三 Tab，`schedule.py status` |
| 改截止日 | US-10 | active 项目 · `set-deadline`（不移动任务） |
| 跳转今日 | — | 点行高亮同 `project_id` pending |

### Hermes 配合

| ID | 命令/改动 |
|----|-----------|
| H-X7 | 新增 `set-deadline --project-id --deadline` |
| （读） | 已有 `status` |

### 工件路径

```
openspec/changes/add-learning-project-status/
  proposal.md · design.md · tasks.md
  tasks-maldaze.md · tasks-hermes.md
  specs/learning-desk-panel/spec.md
  specs/hermes-learning-calendar/spec.md
```

### 验收（MANUAL_QA · M-L8 + M-L9）

见 [MANUAL_QA.md](../MANUAL_QA.md) 域 C。

---

## v1.1 · 面板 L3（`add-learning-desk-panel-l3`）

### 用户价值

| 能力 | v2 对应 | 说明 |
|------|---------|------|
| 增删单任务 | US-15 | `insert` / `remove`，不级联 |
| 周负荷 | US-13 精简 | Week Tab，28 天条形，**小时**单位，超上限标红 |
| 每日上限 | US-1 | MalDaze **设置 → 学习面板**，默认 5h，同步 `profile.json` |
| 自动刷新 | — | FSEvents 监听 `projects.json` |
| 复习通过/失败 | — | `review --result` |

### Hermes 配合

| ID | 命令/改动 |
|----|-----------|
| H-L3 | `today.pending[]` 含 `auto_roll_days` |
| H-L4 | `week-load --from <date> --days 28` |

### 工件路径

```
openspec/changes/add-learning-desk-panel-l3/
  proposal.md · design.md · tasks.md
  tasks-maldaze.md · tasks-hermes.md
  specs/learning-desk-panel/spec.md
  specs/hermes-learning-calendar/spec.md
```

### 验收（MANUAL_QA · [MANUAL_QA.md](../MANUAL_QA.md) 域 C L3）

- insert 后 today 可见；remove 后消失；insert 可选全部 `active` 项目
- 飞书改 `projects.json` 后 1s 内面板刷新（Dashboard 打开时）
- Week Tab 以 **小时** 显示（如 `2.5 小时 / 5 小时`）；超 cap 日标红
- **设置 → 学习面板** 改上限后，今日顶栏与 Week Tab 同步更新；`profile.json` `daily_capacity_minutes` 已写入
- review 失败生成下次复习任务

---

## 已作废 · 日历修复（`fix-learning-rollover-calendar`）

> **CANCELLED (2026-06-08)**：学习域已移除飞书日历投影（`remove-feishu-learning-calendar`）。`rollover` 仅更新 JSON；不再 patch 飞书日历。验收见 [MANUAL_QA.md](../MANUAL_QA.md) 域 C · rollover（C-R1）。

---

## 明确仍不在 follow-up 内

| 项 | 去向 |
|----|------|
| `today_learning.json` 快照 | ROADMAP X5 |
| 拖拽 Gantt | backlog |
| plan / 对话 / 智能模式 | 飞书 Hermes |
| 恢复 SQLite 嵌入 | ❌ |

---

## 推荐实施顺序（v1 之后）

```
v1 归档
    │
    └─► add-learning-desk-panel-l3
            H-L3/H-L4 → MalDaze L3 UI → 归档 v1.1
            │
            └─► add-learning-project-status（X7）
                    Hermes set-deadline → 项目 Tab → M-L8/M-L9 → 归档
            │
            └─► remove-feishu-learning-calendar（Hermes 代码 ✅ · 待 MANUAL_QA 归档）
```
