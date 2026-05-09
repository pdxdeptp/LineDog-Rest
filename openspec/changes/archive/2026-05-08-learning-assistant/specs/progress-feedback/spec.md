## ADDED Requirements

### Requirement: 资源级进度追踪
系统 SHALL 为每个 active 资料展示细粒度进度，追踪模式与 `resources.tracking_mode` 一致：
- `sequential` 资料：进度 = `completed_units / total_units`，进度条以 unit 为粒度
- `pool` 资料：进度 = `completed_count / target_count`（如"已做35/100题"）

#### Scenario: sequential 资料进度更新
- **WHEN** 用户标记某任务为完成（`POST /api/tasks/{id}/complete`）
- **THEN** 关联 unit 的 `completed_at` 写入时间戳，资料进度条即时更新（前端 A 类即时反馈）

#### Scenario: pool 资料进度更新
- **WHEN** 用户标记力扣类任务完成
- **THEN** 该资料的 `completed_count + 1`，进度条即时更新

---

### Requirement: 累计投入小时数
系统 SHALL 追踪并展示用户对每个资料的累计实际投入时间（小时）。该数值只增不减，不受任务删除或重排影响。

#### Scenario: 完成任务时累计
- **WHEN** 用户标记任务完成
- **THEN** 将该任务的 `target_minutes` 累加至对应资料的 `actual_minutes_total` 字段

---

### Requirement: 进度展示双模式
系统 SHALL 支持两种进度展示模式，可在设置中切换，默认两种都显示：
- **表现型**：完成进度百分比 + 进度条（关注"完成了多少"）
- **投入型**：累计投入小时数（关注"付出了多少"）

#### Scenario: 模式切换
- **WHEN** 用户在设置中切换展示偏好
- **THEN** 助手面板中所有资料进度展示方式同步更新，不影响数据存储

---

### Requirement: AI 里程碑系统
系统 SHALL 由 Morning Agent 或 Weekly Review Agent 在检测到显著进展时自动生成里程碑。里程碑由 AI 完全自由发挥命名和时机，目标平均约每3天一个，不固定触发规则。

里程碑 SHALL 通过以下方式呈现：
1. macOS 系统通知（`NSUserNotification` 或 `UNUserNotificationCenter`）
2. 助手面板中的里程碑卡片（置顶显示，直到用户dismiss）

#### Scenario: 里程碑触发
- **WHEN** Morning Agent 或 Weekly Review Agent 检测到以下任意信号：完成率显著提升、某资料达到关键节点（如完成50%）、累计投入小时数跨越整数门槛
- **THEN** AI 生成一条里程碑消息，写入 events 表（`event_type = 'milestone'`），触发 macOS 通知和面板卡片

#### Scenario: 里程碑展示
- **WHEN** 用户打开助手面板
- **THEN** 若存在未 dismiss 的里程碑事件，在面板顶部展示里程碑卡片（含 AI 生成的文案和成就标题）

---

### Requirement: Stats Tab — 监控为主，成就为辅
助手面板 SHALL 包含 Stats Tab，布局分为监控区（上方主体）和成就区（下方次要）。

**监控区**包含：
- 整体进度可行性指示：绿色✓（当前速度可按时完成）或 橙色⚠（存在超期风险）
- 本周/今日实际投入 vs 目标投入（分钟数对比）
- 各资料当前状态列表（进度条 + 预计完成日期 + 风险标记）

**成就区**包含：
- 累计总投入小时数
- 已达成里程碑数量
- 最近3条里程碑历史（时间 + 文案摘要）

#### Scenario: 超期风险标记
- **WHEN** 某资料的 `remaining_units × avg_estimated_minutes > (deadline - today) × daily_capacity_min`
- **THEN** 该资料在 Stats Tab 中显示橙色⚠标记和预估超期天数

---

### Requirement: 四个时机的进度反馈
系统 SHALL 在以下四个时机提供进度反馈，覆盖即时到定期的全频谱：

| 时机 | 触发 | 呈现 |
|------|------|------|
| A 即时 | 用户打勾完成任务 | 进度条动画更新 |
| B 每日 | Morning Briefing | 摘要中包含一行进度亮点（如"灵茶山已完成40%，进度良好"） |
| C 每周 | Weekly Review 总结 | 本周各资料完成情况汇总 |
| D 随时 | 用户打开 Stats Tab | 完整监控看板 |

系统 SHALL NOT 实现连续打卡（streak）机制。

#### Scenario: Morning Briefing 进度亮点
- **WHEN** Morning Agent 生成今日摘要
- **THEN** 摘要中包含一句 AI 生成的进度亮点语，反映当前整体状态（正向激励或风险提醒）
