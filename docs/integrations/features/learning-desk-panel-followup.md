# 学习桌宠面板 · 延后工作索引（follow-up）

Hub：[learning-desk-panel.md](./learning-desk-panel.md) · 总目录：[../ROADMAP.md](../ROADMAP.md) §7

> **状态**：文档就绪（2026-06-07）· **前置**：[`add-learning-desk-panel`](../../../openspec/changes/add-learning-desk-panel/) v1（L1+L2+H-L2）完成

scope-decision **A** 将面板拆成三档交付；本文汇总 **v1 之后**全部已写清的 OpenSpec 与任务，避免 apply v1 时 scope drift。

---

## 交付分档

| 档位 | OpenSpec change | 内容 | 阻塞关系 |
|------|-----------------|------|----------|
| **v1（当前 apply）** | `add-learning-desk-panel` | 三栏、Today 只读、complete、move+dry-run | — |
| **v1.1 面板增强** | `add-learning-desk-panel-l3` | insert/remove、Week、FSEvents、review | 依赖 v1 |
| **日历修复（独立）** | `fix-learning-rollover-calendar` | rollover patch 飞书日历 | 可与 v1 并行 |

---

## v1.1 · 面板 L3（`add-learning-desk-panel-l3`）

### 用户价值

| 能力 | v2 对应 | 说明 |
|------|---------|------|
| 增删单任务 | US-15 | `insert` / `remove`，不级联 |
| 周负荷 | US-13 精简 | Week Tab，14–28 天条形 |
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

### 验收（MANUAL_QA 扩展，v1.1 完成后编写）

- insert 后 today 可见；remove 后消失
- 飞书改 `projects.json` 后 1s 内面板刷新（Dashboard 打开时）
- Week Tab 超 cap 日标红
- review 失败生成下次复习任务

---

## 日历修复 · rollover（`fix-learning-rollover-calendar`）

### 问题

`rollover` 更新 JSON `scheduled_date`，但**不 patch** `feishu_event_id` → 飞书日历格子落后。

### 范围

- **仅 Hermes** `cmd_rollover` + 单测/smoke
- MalDaze **无代码**；面板不读日历

### 工件路径

```
openspec/changes/fix-learning-rollover-calendar/
  proposal.md · design.md · tasks.md · tasks-hermes.md
  specs/hermes-learning-calendar/spec.md
```

### 验收

- 昨日未完成任务 → `rollover` → JSON 与飞书全天格 **同一天**
- patch 失败：JSON 仍滚入；输出 `calendar_errors`

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
    ├─► fix-learning-rollover-calendar（Hermes，可与 v1 并行）
    │
    └─► add-learning-desk-panel-l3
            H-L3/H-L4 → MalDaze L3 UI → 归档 v1.1
```
