# 实施任务索引

本 change 跨 **MalDaze** 与 **Hermes**，任务分文档维护：

| 文档 | 范围 | 建议顺序 |
|------|------|----------|
| [tasks-hermes.md](./tasks-hermes.md) | `~/.hermes` skills、脚本、晨报、学习日历 | 域 A → 域 C → 域 D → 域 B 写端 |
| [tasks-maldaze.md](./tasks-maldaze.md) | 本 repo 域 B 消费者（D3：不改 Smart Input） | 域 B 契约就绪后 |

**文档任务**（本 change 已创建大部分，实施前核对）见 §0。

`opsx:apply` 默认执行 **MalDaze** 任务。Hermes 任务在 `~/.hermes` 按 [tasks-hermes.md](./tasks-hermes.md) 执行。

总目录任务 ID 对照：[docs/integrations/ROADMAP.md](../../../docs/integrations/ROADMAP.md)

## 依赖关系

```
§0 文档 ──► OpenSpec + features/*.md
    │
    ├─► tasks-hermes 域 A ──► 日待办端到端
    ├─► tasks-hermes 域 C ──► 学习日历策略
    ├─► tasks-hermes 域 D ──► 晨报扩展
    │
    ├─► tasks-hermes 域 B 写端 ──┐
    │                             ├──► 煮红薯联调
    └─► tasks-maldaze 域 B 读端 ──┘
```

## §0 文档（Phase 0）

- [x] 0.1 `docs/integrations/ROADMAP.md` 总目录
- [x] 0.2 OpenSpec `unify-personal-assistant` proposal / design / specs / tasks
- [x] 0.3 `docs/integrations/features/day-reminders.md`
- [x] 0.4 `docs/integrations/features/desk-intervention.md`
- [x] 0.5 `docs/integrations/features/learning-calendar.md`
- [x] 0.6 更新 `docs/integrations/hermes.md` 集成登记表（域 A/B 待联调状态已同步）
- [x] 0.7 更新 `~/.hermes/docs/integrations/README.md` manifest 索引行

## MalDaze 任务摘要

详见 [tasks-maldaze.md](./tasks-maldaze.md)。

## Hermes 任务摘要

详见 [tasks-hermes.md](./tasks-hermes.md)。
