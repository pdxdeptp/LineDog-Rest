## ADDED Requirements

### Requirement: 固定骨架 + 有限回退架构
Conversational Planner SHALL 使用固定 Graph 拓扑：Plan → Gather（并行）→ Propose → Human Review → Execute。路由权归 Graph，LLM 仅决策各节点内容。Propose 节点在信息不足时可回退 Gather 至多一次，由 `gather_iterations` 计数器强制上限。系统 SHALL NOT 使用 ReAct 风格的自由循环路由。

#### Scenario: 单意图处理
- **WHEN** 用户输入"把今天的八股换成项目时间"
- **THEN** Plan 节点识别意图并确定需要调用 `get_task_stats`；Gather 节点并行执行读工具；Propose 节点生成 swap 变更提案；Graph 路由至 Human Review 等待用户确认；用户确认后 Execute 节点写入

#### Scenario: 组合意图处理
- **WHEN** 用户输入"我想摆了，同时把下周的八股减半"
- **THEN** Plan 节点识别组合意图，Gather 并行调用多个读工具，Propose 生成包含两项变更的单一提案，一次 Human Review 请求用户确认

#### Scenario: 信息不足回退
- **WHEN** Propose 节点判断 Gather 返回的数据不足以生成完整提案，且 gather_iterations < 1
- **THEN** Graph 路由回 Gather 节点补充读取，gather_iterations + 1；若 gather_iterations 已达上限则继续用现有信息生成提案

---

### Requirement: 标准工具集
系统 SHALL 提供以下工具供 Conversational Planner 的 Gather 节点并行调用（读工具）和 Execute 节点写入（写工具）：

| 工具 | 签名 | 阶段 | 说明 |
|------|------|------|------|
| `get_current_plan` | `() → str` | Gather | 读取 plan.md 全文 |
| `get_task_stats` | `(period: str) → dict` | Gather | 查询完成率、任务分布（period: today/this_week/last_week） |
| `get_resource_progress` | `(resource_id: int) → dict` | Gather | 某资料当前进度（completed/total units） |
| `check_capacity` | `(start: date, end: date) → dict` | Gather | 该时间段每日剩余可用工时 |
| `update_tasks` | `(patch: list) → dict` | Execute | 增删改任务，用户确认后真正写入 DB |
| `rewrite_plan` | `(content: str) → None` | Execute | 更新 plan.md，用户确认后执行 |

`present_proposal` 和 `apply_confirmed_change` 是 Graph 节点（Human Review 和 Execute），不是 LLM 可调工具。

#### Scenario: 写操作必须经用户确认
- **WHEN** Propose 节点生成变更提案后
- **THEN** Graph 路由至 Human Review 节点（LangGraph interrupt），向用户展示变更摘要，等待 [确认] 或 [取消]；用户取消时不修改任何数据；用户确认后 Graph 路由至 Execute 节点执行写入

---

### Requirement: 减载意图识别与处理
系统 SHALL 识别表达"降低负荷"语义的自然语言（"我想摆了"/"撑不住了"/"今天不行"/"放松一下"等），并生成对应的减载提案。

#### Scenario: 短期减载（今日）
- **WHEN** 用户表达今日低负荷意图
- **THEN** 系统生成提案：将今日超出 `reduced_capacity_min` 的任务顺延，展示简化后的今日清单

#### Scenario: 减载周建议
- **WHEN** 用户表达持续疲劳或明确说"想摆一周"
- **THEN** 系统生成提案：将 `load_mode` 切换为 `reduced`，持续至下个周日，期间 Morning Agent 使用 `reduced_capacity_min`

#### Scenario: 恢复状态意图
- **WHEN** 用户输入"我还能学"/"状态不错"/"今天多做点"
- **THEN** 系统查询今日剩余 capacity 后，提案追加可选任务（从同一资料的下一个未完成 unit 取），展示给用户确认

---

### Requirement: 计划调整意图处理
系统 SHALL 处理以下类型的规划调整意图：

#### Scenario: 任务 swap
- **WHEN** 用户输入"把今天的[任务A]换成[任务B]"
- **THEN** 系统在 tasks 表中交换两个任务的 scheduled_date，呈现 diff 给用户

#### Scenario: 资料进度调整
- **WHEN** 用户输入"这章比想象中难，我需要多一周"
- **THEN** 系统识别当前资料，将该资料后续所有 unit 的 tasks 整体右移7天，检查是否影响 deadline，呈现影响摘要

#### Scenario: deadline 可行性查询
- **WHEN** 用户输入"七月来不及了吗" / "能赶上吗"
- **THEN** 系统计算所有 active 资料剩余工时 vs 剩余可用 capacity，以"X资料可能超期，缺口Y天"格式返回分析，不自动修改计划

---

### Requirement: 对话历史与上下文
Conversational Planner SHALL 在单次对话会话内维护完整消息历史（in-memory），支持多轮追问。跨会话不主动恢复历史，但用户可通过工具访问历史事件（events 表）。

#### Scenario: 多轮追问
- **WHEN** 用户在上一轮后继续补充"另外把周四的力扣也取消掉"
- **THEN** LLM 结合上一轮已生成的变更集，合并新请求，生成统一提案
