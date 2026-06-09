# 实施任务索引 · rollover 日历同步

> **CANCELLED (2026-06-08)**：学习域已移除飞书日历投影（`remove-feishu-learning-calendar`）。rollover 仅更新 JSON；本 change 不再实施或归档。

> **仓库**：仅 Hermes（`~/.hermes`）。MalDaze 无任务。

| 文档 | 范围 |
|------|------|
| [tasks-hermes.md](./tasks-hermes.md) | H-L1 全部 |

**可与** `add-learning-desk-panel` v1 **并行**（无文件重叠）。

## 依赖

```
域 C C1/C2 已上线
    │
tasks-hermes §1–3
    │
手工：昨日未完成任务 → rollover → 日历日期对齐
    │
ROADMAP H-L1 → ✅
```
