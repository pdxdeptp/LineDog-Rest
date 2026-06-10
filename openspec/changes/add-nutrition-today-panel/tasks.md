# 实施任务索引 · add-nutrition-today-panel

> ROADMAP X2 · explore 定稿：方案 A + 左栏 60/40 + 受控 log 交互

| 文档 | 范围 |
|------|------|
| [tasks-hermes.md](./tasks-hermes.md) | `_refresh_panel`、归档、晨报、skill、单测 |
| [tasks-maldaze.md](./tasks-maldaze.md) | 契约、FSEvents、左栏 UI、单测 |

## 依赖

```
tasks-hermes _refresh_panel + 单测
        │
tasks-maldaze 契约 + UI + FSEvents
        │
docs + MANUAL_QA → 归档
```

## 并行注意

- 与 `extend-learning-today-*` 避免同时大改 `DashboardRootView` 非左栏区域。
- Hermes 仓 `~/.hermes` 与 MalDaze 可并行至 MalDaze 集成前。
