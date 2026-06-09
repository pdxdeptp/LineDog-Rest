# 实施任务索引 · v1 only

> **范围**：L1 + L2 + H-L2。L3 / H-L1 / H-L3 / H-L4 → 见 follow-up changes（文档已写好）。

| 文档 | 范围 |
|------|------|
| [tasks-maldaze.md](./tasks-maldaze.md) | MalDaze L1 + L2 |
| [tasks-hermes.md](./tasks-hermes.md) | Hermes H-L2 only |

| Follow-up | 路径 |
|-----------|------|
| 面板 L3 增强 | [add-learning-desk-panel-l3](../add-learning-desk-panel-l3/) |
| rollover 日历同步 | [fix-learning-rollover-calendar](../fix-learning-rollover-calendar/) |

`opsx:apply` 默认 **tasks-maldaze**；L2 前须完成 **tasks-hermes §1**。

## 依赖

```
tasks-hermes H-L2 (move --dry-run)
    │
tasks-maldaze L1 (只读)
    │
tasks-maldaze L2 (complete + move)
    │
MANUAL_QA M-L-1～6 → 归档 v1
```

## §0 文档

- [x] 0.1 `learning-desk-panel.md` 母本
- [x] 0.2 `add-learning-desk-panel` OpenSpec v1 收窄
- [x] 0.3 follow-up：`add-learning-desk-panel-l3`、`fix-learning-rollover-calendar`
