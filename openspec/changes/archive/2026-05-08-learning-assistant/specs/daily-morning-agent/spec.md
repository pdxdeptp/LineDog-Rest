## ADDED Requirements

### Requirement: 开机触发，每天一次
系统 SHALL 在桌宠启动时由 `BackendProcessManager` spawn 后端（若端口未占用），APScheduler 在后端进程内每天 8:00 触发一次 Morning Agent，调用 `POST /api/morning-briefing`。同一日历日内重复触发 SHALL 被后端幂等处理（检查当日是否已生成 briefing）。

> **[实施后修订 2026-05-08]** 触发机制从 LaunchAgent 改为 Swift AppDelegate spawn + APScheduler，见 design.md 决策 5。

#### Scenario: 桌宠启动触发
- **WHEN** 用户打开桌宠，BackendProcessManager 探测 8765 端口空闲并 spawn 后端
- **THEN** 后端启动后 APScheduler 在 8:00 触发 Morning Agent；若启动时 8:00 已过且当日 briefing 未生成，则立即补触发

#### Scenario: 重复触发幂等
- **WHEN** 同一天内 `/api/morning-briefing` 被多次调用
- **THEN** 后端返回当日已生成的 briefing，不重复执行重排或 LLM 调用

---

### Requirement: 未完成任务重排
Morning Agent SHALL 查询前一日 `completed_at IS NULL` 的所有任务，将其重新调度到今日或最近有 capacity 的日期。

#### Scenario: 昨日未完成任务重排至今日
- **WHEN** 今日剩余 capacity ≥ 未完成任务的 target_minutes 之和
- **THEN** 将这些任务的 `scheduled_date` 更新为今日，`reschedule_count + 1`，`originally_scheduled_date` 保持不变

#### Scenario: 今日容量不足，溢出后推
- **WHEN** 未完成任务数量超过今日剩余 capacity
- **THEN** 按任务优先级（priority 字段）填满今日，剩余任务顺延至后续最近空档；每次调度均 `reschedule_count + 1`

#### Scenario: 无未完成任务
- **WHEN** 前一日所有任务均已完成（或当日为系统初始日）
- **THEN** Morning Agent 跳过重排步骤，直接生成当日摘要

---

### Requirement: 生成当日摘要
Morning Agent SHALL 生成今日任务摘要，包含：任务列表（含各任务标题和 target_minutes）、今日总预估工时、所属资料进度上下文。

#### Scenario: 摘要推送到 MalDaze
- **WHEN** Morning Agent 完成摘要生成
- **THEN** 后端通过 API 响应或推送通知，将摘要数据发送给 MalDaze 前端，前端更新助手面板中栏显示

#### Scenario: Weekly Review 补触发检查
- **WHEN** Morning Agent 启动时
- **THEN** 系统查询 events 表，若上周日（最近一个周日）不存在 `event_type = 'weekly_review_done'` 的记录，Graph 优先执行 Weekly Review 子图，完成后继续生成今日摘要；若记录已存在则跳过

---

### Requirement: 无显式"跳过"或"状态不好"操作
系统 SHALL NOT 提供任务跳过按钮或能量状态选择界面。系统通过 `reschedule_count`、完成时间戳等被动信号感知用户节奏，在 Weekly Review 时汇总分析。

#### Scenario: 用户不完成任务
- **WHEN** 用户当日未标记某任务为完成
- **THEN** 次日 Morning Agent 自动将该任务纳入重排，无需用户任何操作

#### Scenario: 用户表达轻负荷意图
- **WHEN** 用户在对话框输入"今天不想做"/"我想摆了"等
- **THEN** 请求路由至 Conversational Planner 处理，不在 Morning Agent 层面处理

---

### Requirement: 每日 capacity 配置
系统 SHALL 从 `system_state` 读取 `daily_capacity_min`（默认300分钟/5小时）和 `reduced_capacity_min`（减载周使用，默认60分钟）。当前 `load_mode` 决定使用哪个 capacity 值。

#### Scenario: 正常模式 capacity
- **WHEN** `system_state.load_mode = 'normal'`
- **THEN** Morning Agent 使用 `daily_capacity_min` 作为今日可用工时上限

#### Scenario: 减载模式 capacity
- **WHEN** `system_state.load_mode = 'reduced'`
- **THEN** Morning Agent 使用 `reduced_capacity_min` 作为今日可用工时上限，超出部分任务顺延
