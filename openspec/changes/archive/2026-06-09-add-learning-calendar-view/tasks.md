# 实施任务索引 · X8 · 日程双视图（方案 C）

> **产品决策**：上方月历缩略 + 下方 Agenda；**取代**「周负荷」Tab。

| 文档 | 范围 |
|------|------|
| [tasks-hermes.md](./tasks-hermes.md) | `schedule-range` CLI、单测、smoke |
| [tasks-maldaze.md](./tasks-maldaze.md) | 日程 Tab UI、ViewModel、验收 |

## 任务清单

### 文档

- [x] D1 `learning-desk-panel.md` / `ROADMAP.md` X8 / `hermes.md` 一句
- [x] D2 `MANUAL_QA.md` M-L10 日程验收

### Hermes

- [x] H1 `schedule-range` 子命令
- [x] H2 单测 + `integration_smoke`

### MalDaze

- [x] M1 Models + CLI
- [x] M2 `LearningScheduleView`（月历 + Agenda）
- [x] M3 ViewModel 替换 week Tab + 刷新链
- [x] M4 单测

### 收尾

- [x] V1 MANUAL_QA M-L10 通过
- [x] V2 归档（用户确认后）
