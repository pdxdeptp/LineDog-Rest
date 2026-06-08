## Context

见 [learning-desk-panel.md](../../../docs/integrations/features/learning-desk-panel.md)。本 change 仅交付 **v1（L1+L2+H-L2）**；L3 与 H-L1/H-L3/H-L4 见 follow-up changes。

**ROADMAP**：Phase 6a · [ROADMAP.md](../../../docs/integrations/ROADMAP.md) §7.1

## Goals / Non-Goals

**Goals（v1）:**

- 中栏 Today 与 `schedule.py today` 一致（预算、warnings、滚入角标自嵌套 task 字段）。
- complete；move + dry-run 预览确认。
- fail-loud；左右栏无回归。

**Non-Goals（v1 · 见 follow-up 文档）:**

- insert / remove / Week Tab / FSEvents / review 按钮 → `add-learning-desk-panel-l3`
- rollover 飞书日历 patch → `fix-learning-rollover-calendar`
- SQLite、飞书日历 SSOT、Swift 级联、plan/智能模式。

## Decisions

（Decision 1–7 同母本；v1 仅实现 L1/L2 子集。）

### Decision 8: v1 与 follow-up 分界

| 能力 | v1 change | follow-up |
|------|-----------|-----------|
| Today 只读 | ✅ | — |
| complete / move | ✅ | — |
| move --dry-run | ✅ H-L2 | — |
| insert / remove | — | l3 change |
| Week 负荷 | — | l3 + H-L4 |
| FSEvents | — | l3 change |
| review passed/failed | — | l3 change |
| rollover 日历 | — | fix-learning-rollover-calendar |
| pending auto_roll_days | v1 从 study.tasks 合并 | H-L3 简化解析 |

### Decision 9: L2 依赖 H-L2（已闭合 OQ-1）

MalDaze L2 move **不得**在无 dry-run 时假装完整预览；须先完成 `tasks-hermes.md` §1 或同 PR 内 Hermes 子任务。

## Risks / Trade-offs

- **DashboardRootView 与工作区并行改动** → 串行 apply，不并行子 agent。
- **沙盒 spawn python3** → L1 首项验证；错误卡指引 `HERMES_HOME`。

## Migration Plan

1. H-L2（或同迭代）→ L1 Today → L2 complete/move → MANUAL_QA M-L-1～6 → 归档 v1。
2. 再开 `add-learning-desk-panel-l3`、`fix-learning-rollover-calendar`（文档已就绪）。

## Open Questions

（v1 无开放项；L3/OQ-2/OQ-3 移至 l3 change。）
