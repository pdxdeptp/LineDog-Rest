## Context

睡眠调整功能跨 MalDaze（macOS 桌宠）与 Hermes（个人 agent 数据栈）两个系统。探索阶段已确定职责拆分：Hermes 算目标、写 JSON、推晨报；MalDaze 读 JSON、弹提醒、霸屏。

**运行时耦合总览（首选）**：[docs/integrations/hermes.md](../../../docs/integrations/hermes.md)

本 change 的详细设计按仓库/运行时拆成两份文档：

| 文档 | 范围 |
|------|------|
| [design-maldaze.md](./design-maldaze.md) | Swift 桌宠：提醒链、UI 复用、合盖取消、设置、错误处理 |
| [design-hermes.md](./design-hermes.md) | Python Hermes：pmset、目标算法、晨报、cron 集成、JSON 写入 |

共享契约（路径、Schema、强耦合声明）在两份文档中均引用，权威定义见 spec `sleep-schedule-contract`。

## Goals / Non-Goals

**Goals:**

- 单一 JSON 契约集成，排查路径固定。
- MalDaze 不解析 pmset、不调目标、不推晨报。
- Hermes 不实现铃铛/霸屏。
- 契约违反时 fail-loud，不静默降级。
- 达标容错：目标时刻后 ≤10 分钟内合盖算达标；提前合盖也算达标。

**Non-Goals:**

- 零耦合 / 公开 API 化 Hermes 数据。
- MalDaze 内晨报或睡眠历史 UI。
- 新铃铛/霸屏 UI 实现。
- 周末例外或旅行模式。
- 在本 change 中修改 Hermes cron 调度时间（保持现有 `0 8 * * *`）。

## Decisions

### Decision 1: 分文档记录 MalDaze vs Hermes 实现

`design-maldaze.md` 与 `design-hermes.md` 并列；`tasks-maldaze.md` 与 `tasks-hermes.md` 并列。`opsx:apply` 默认先执行 MalDaze tasks；Hermes tasks 需在同一机环境的 `~/.hermes` 手动或通过 agent 完成。

### Decision 2: 提醒时刻语义

- `targetBedtime` = 截止铃铛（如「要睡觉了」）。
- `lockBedtime` = Hermes 写入的 `targetBedtime + 5min`，霸屏触发时刻。
- 删除独立的「T-5 预警」节点；deadline 铃铛即最后软提醒。

### Decision 3: dayType 缺失即失败

强耦合假设下，Hermes 每日 cron 必须写入完整契约；MalDaze 缺字段不调度、不默认 `training`。

## Risks / Trade-offs

- **[Risk] Hermes cron 未跑 → JSON 过期** → MalDaze 继续用上次 `updatedAt` 调度并打日志；用户看 Hermes 晨报是否送达。
- **[Risk] 08:00 更新 vs 深夜 deadline** → 对正常作息无影响；见 design-hermes。
- **[Risk] 跨午夜时间比较** → Hermes 用同一「睡眠夜」datetime；MalDaze 只读 HH:mm 配合当日日历。
- **[Risk] 与番茄霸屏冲突** → 睡眠霸屏优先；见 design-maldaze。

## Migration Plan

1. 先落地 Hermes：`sleep_tracker` + 初始 `sleep_schedule.json`（`targetBedtime: "00:00"`, `lockBedtime: "00:05"`）。
2. 再落地 MalDaze：读契约、调度提醒；默认总开关 **关闭**，用户手动开启。
3. 验证一晚：cron 更新 JSON → 桌宠重载 → 提醒按新 target 触发。

## Open Questions

- 无（探索阶段决策已收敛）。若实施中发现 `presentCenterBellReminder` 与 7 分钟倒计时并发问题，在 MalDaze 任务中单独处理取消/互斥。
