## Context

- 手动番茄由 `ManualTimerEngine` 驱动：`AppViewModel.handleTimeState` 映射 `.working` / `.resting`；工作段结束在 engine `tick()` 从 working 切 resting 时发生。
- 学习面板已有 per-task `actual_minutes`（Hermes `complete --actual-minutes`），粒度是**任务完成**；与本 change 的 **session 事件** 分层，P1 不连通。
- 本地持久化先例：`TodayTodoStore` → `~/Library/Application Support/MalDaze/today-todo.json`。

## Goals / Non-Goals

**Goals:**

- 以 **时间 + 番茄** 为 P1 SSOT：每条 session 必有 `startedAt`、`endedAt`、`durationMinutes`。
- 零摩擦记录：用户无需为每条 session 贴标签。
- Dashboard 右栏「今日专注」：汇总 + 列表 + 进行中 live 行。
- 全量保留历史 session 文件；UI 仅展示当天。

**Non-Goals:**

- Pin、labels、学习任务/Todo 拖入、一键完成代入时长。
- Hermes 契约或 `daily_log` 写入。
- 整点/半点模式 session（仅手动番茄工作段）。
- 历史日浏览、编辑/删除 session、导出、 streak 统计。

## Decisions

### D1: MalDaze-local session SSOT

- **Decision**: `focus-sessions.json` 由 MalDaze 独占读写；append-only，无 purge。
- **Rationale**: 与 AGENTS.md SSOT 边界一致；Hermes 管学习完成，MalDaze 管专注事件。
- **Alternative rejected**: 写 Hermes — P1 范围过大且语义不同（未完成任务的 partial time）。

### D2: 何时写入 session

| 事件 | 行为 |
|------|------|
| 工作段自然结束 → 休息 | 写入 `source: completed` |
| 手动模式 `.working` 期间点「停止计时」 | 写入 `source: stoppedEarly`，`durationMinutes` = 实际 |
| 休息段停止 / 跳过休息 | 不写入 |
| 整点模式 | P1 不写入 |

- **Implementation note**: `AppViewModel` 在工作段开始时记录 `workSegmentStartedAt`；在 transition to rest 或 stop-while-working 时 finalize。

### D3: 日历日与展示过滤

- **Decision**: session 的 `date` 字段取 `endedAt` 的本地日历日；Dashboard 只展示 `date == today`。
- **Rationale**: 跨午夜极少；以结束日归档简单可测。

### D4: 汇总与计数规则（用户已定）

- 汇总：`N 个番茄 · 共 X 分钟` — **不**拆分完整 vs 提前结束。
- `N` = 当日已 finalize 的 session 条数（不含进行中）。
- `X` = 已 finalize 的 `durationMinutes` 之和 + 进行中段当前已进行分钟（live）。
- 列表时间格式：`14:00–14:25`（起止）；提前结束加「提前结束」小字。
- 进行中行：`14:35–进行中 · 已 12 分钟`，固定置顶；整秒更新。

### D5: UI 位置

- **Decision**: 右栏 `statusChip` 与 `controlsQuickActions` 之间插入「今日专注」区块。
- **Rationale**: 与 live 状态邻近；不挤占 primary action 区。

### D6: 数据模型（P1）

```json
{
  "schemaVersion": 1,
  "sessions": [
    {
      "id": "uuid",
      "date": "2026-06-20",
      "startedAt": "2026-06-20T14:00:00Z",
      "endedAt": "2026-06-20T14:25:00Z",
      "durationMinutes": 25,
      "source": "completed",
      "labels": []
    }
  ]
}
```

- `labels`: 预留空数组；P1 不 UI。

### D7: 与 suspended timer 的交互

- 停止计时若发生在工作段：finalize session，然后走现有 suspend 流程。
- 恢复计时开始**新**工作段 → 新 `workSegmentStartedAt`；不续写上一段。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| Engine 回调线程与 MainActor | 沿用现有 `Task { @MainActor }` 路径 finalize |
| 文件无限增长 | P1 接受；后续可加 archive，不在本 change |
| 进行中 live 与 engine 漂移 | 以 `workSegmentStartedAt` + `Date()` 差值为准，与 status line 同频 |
| 误在 rest 段 stop 产生 session | 仅在 `manualEngine` running 且非 `isInRestPhase` 时 finalize early stop |

## Migration Plan

- 新文件；无迁移。首次运行 `focus-sessions.json` 不存在则创建空 `{ schemaVersion: 1, sessions: [] }`。
- 回滚：移除 UI + store hook；遗留 JSON 无害。

## Open Questions

- None for P1（格式、汇总、live、全保留均已定）。
