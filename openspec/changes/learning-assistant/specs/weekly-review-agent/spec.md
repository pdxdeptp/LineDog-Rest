## ADDED Requirements

### Requirement: 周日定时触发
系统 SHALL 通过 APScheduler 在每周日 20:00 触发 Weekly Review Agent。若后端进程在触发时刻未运行，SHALL 在下次 Morning Agent 启动时补触发。

#### Scenario: 后端在线时准时触发
- **WHEN** 每周日 20:00，APScheduler 调度器运行中
- **THEN** Weekly Review Agent Graph 立即启动，开始聚合本周数据

#### Scenario: 后端离线补触发
- **WHEN** 周日 20:00 时后端进程未运行
- **THEN** 系统在 DB 中写入 `system_state.pending_weekly_review = 'true'`；下次 Morning Agent 启动时检测到此 flag，优先执行 Weekly Review，完成后将 flag 重置为 'false'

---

### Requirement: 本周数据聚合
Weekly Review Agent SHALL 聚合以下维度数据用于分析：

- 本周各资料完成率（completed tasks / scheduled tasks）
- 各资料实际工时 vs 预估工时
- 任务重排次数分布（哪类任务被反复推迟）
- 当前距 deadline 剩余天数 vs 剩余总工时

#### Scenario: 完成率计算
- **WHEN** Weekly Review Agent 启动
- **THEN** 查询 tasks 表本周（周一00:00 - 周日23:59）所有 scheduled_date 在此范围内的任务，计算 completed_at IS NOT NULL 的比例

#### Scenario: 剩余工时 vs deadline 校验
- **WHEN** 聚合完成后
- **THEN** 对每个 status='active' 的资料，计算 remaining_units × avg_estimated_minutes，与 (deadline - today) × daily_capacity_min 对比，标记是否存在超期风险

---

### Requirement: 减载建议
Weekly Review Agent SHALL 基于以下信号判断是否建议减载周：本周完成率 < 60%，或本周 reschedule_count 总和 > 阈值（默认5次）。建议 SHALL 在审核草稿中呈现，不自动切换 load_mode。

#### Scenario: 建议减载
- **WHEN** 本周完成率 < 60% 或 reschedule_count 总和 > 5
- **THEN** 在下周计划草稿中增加"建议下周设为减载周"提示，并展示减载方案与正常方案的对比

#### Scenario: 不建议减载
- **WHEN** 本周数据正常
- **THEN** 直接生成标准下周计划草稿，不显示减载选项

---

### Requirement: 下周计划草稿生成
Weekly Review Agent SHALL 基于本周聚合数据和当前 plan.md，生成下周每日任务分配草稿。草稿需考虑：各资料剩余进度、deadline 压力、load_mode 设置。

#### Scenario: 草稿生成
- **WHEN** 数据聚合完成
- **THEN** 系统生成下周7天的任务分配列表，每天任务总 estimated_minutes ≤ 当前 daily_capacity_min

#### Scenario: deadline 优先级调整
- **WHEN** 某资料存在超期风险
- **THEN** 该资料的任务在下周草稿中获得更高 priority（priority=1），在 Morning Agent 重排时优先保留

---

### Requirement: 人工审核与确认
Weekly Review Agent SHALL 使用 LangGraph interrupt 暂停，将下周计划草稿和本周总结推送给用户审核。用户可直接确认、修改后确认，或放弃。

#### Scenario: 用户确认草稿
- **WHEN** 用户点击确认
- **THEN** 系统将下周 tasks 写入 tasks 表，更新 plan.md，写入 plan_versions 快照，记录 `weekly_review_done` 事件

#### Scenario: 用户修改后确认
- **WHEN** 用户在审核界面调整某些任务后确认
- **THEN** 系统以用户最终版本为准写入，而非 Agent 原始草稿

#### Scenario: 用户放弃
- **WHEN** 用户关闭审核界面或点击取消
- **THEN** 系统不写入任何数据，下周 Morning Agent 依据现有 tasks 重排运行
