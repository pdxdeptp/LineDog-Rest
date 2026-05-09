## Context

MalDaze 是一个已上线的 macOS 桌宠应用（Swift/SwiftUI），拥有番茄钟、Apple Reminders 同步待办、自然语言智能提醒等功能，并已集成 Gemini API。当前 `assistant_backend/` 目录已清空，后端从零搭建。

用户目标：在约10周内完成秋招 Agent 开发岗的备考（力扣、Agent 框架学习、八股、简历），需要一套能自动解析学习资料、自适应调整计划、支持自然语言交互的规划系统，直接嵌入 MalDaze 桌宠中使用。

约束：
- 单用户本地应用，无多机同步需求
- Gemini API Key 已有（沿用）
- 前端必须是 MalDaze（Swift），不另起 Web UI
- 时间有限，MVP 优先，预留扩展接口

## Goals / Non-Goals

**Goals:**
- Material Ingestion：任意学习资料 URL → 解析 → 估时 → 任务草稿 → 用户审核 → 写入
- Morning Agent：开机触发，重排未完成任务，生成当日摘要
- Conversational Planner：自然语言意图 → 工具调用 → 计划变更提案 → 用户确认 → 执行
- Weekly Review：周日定时触发（含离线补偿），减载建议，人工审核
- 数据层：SQLite + plan.md，完整 schema，不依赖外部数据库服务
- Swift 前端：三栏布局，中栏学习面板，HTTP 与后端通信

**Non-Goals:**
- 多用户 / 云端同步
- 移动端（健身/餐饮助手在后续 milestone）
- 纯意图型资料（"我想学 LangGraph"，不带具体资料链接）
- 八股爬虫（小红书爬取）
- 向量数据库 / 语义搜索（留接口不实现）
- 心理 Therapist 功能（留接口不实现）
- Effort estimation 自适应校准（方案 D，后期优化）

## Decisions

### 决策 1：后端技术栈 — FastAPI + LangGraph + aiosqlite

**选择**：FastAPI（HTTP 框架）+ LangGraph（Agent 编排）+ aiosqlite（异步 SQLite）+ APScheduler（定时任务）+ google-generativeai（LLM）

**理由**：依赖已在原 pyproject.toml 中定义；LangGraph 的 interrupt 机制天然适配"生成草稿 → 用户审核 → 执行"的人在环设计；aiosqlite 与 FastAPI 异步模型吻合。

**备选方案放弃原因**：PostgreSQL — 单用户本地应用无需独立数据库服务，运维复杂度不值得；Celery — APScheduler 嵌入式更轻量；其他 LLM 框架 — Gemini 已有集成经验。

---

### 决策 2：存储 — SQLite（本地文件）+ plan.md 双轨

**选择**：`learning.db`（SQLite，运营数据）+ `plan.md`（Markdown，战略文档，Agent 直接读写）

**理由**：
- plan.md 是给 LLM 读的"大脑"——Markdown 格式 LLM 天然理解，版本变更可用 git 追踪，人工也可直接编辑
- SQLite 处理结构化查询（完成率统计、任务重排、capacity 计算），这些用 Markdown 做代价高
- 两者分工清晰：plan.md 是"计划长什么样"，DB 是"发生了什么"

**plan.md 作为 source of truth**：每次 Agent 修改 plan.md 后，将全文快照写入 `plan_versions` 表。

---

### 决策 3：Conversational Planner — 固定骨架 + 有限回退

**选择**：固定 Graph 拓扑（Plan → Gather → Propose → Human Review → Execute），路由权归 Graph，内容决策归 LLM，Propose 节点可回退 Gather 至多一次。

**Graph 拓扑**：
```
START → Plan → Gather → Propose ──→ Human Review → Execute → END
                 ↑          │
                 └──────────┘
              （gather_iterations < 1 时允许回退，Graph 用计数器强制上限）
```

**各节点职责**：

| 节点 | 执行者 | LLM 决策内容 |
|------|--------|-------------|
| Plan | LLM | 意图是什么，需要调用哪些读工具 |
| Gather | Graph（无 LLM）| 并行执行所有读工具，结果汇总 |
| Propose | LLM | 提案内容是什么，信息是否充分 |
| Propose → 路由 | Graph | 走 Human Review 还是回退 Gather（LLM 无法干预） |
| Human Review | Graph interrupt | 等用户确认，无 LLM |
| Execute | Graph（无 LLM）| 写 DB / plan.md，固定操作 |

**工具集**（Gather 节点并行调用，Execute 节点写入）：
```
读工具（Gather 阶段并行执行）：
  get_current_plan()          → 读 plan.md
  get_task_stats(period)      → 查询完成率/分布
  get_resource_progress(id)   → 某资料当前进度
  check_capacity(date_range)  → 某时段剩余工时

写工具（Execute 阶段，用户确认后执行）：
  update_tasks(patch)         → 增删改任务
  rewrite_plan(content)       → 更新 plan.md
```

**正常路径**：2 次 LLM 调用（Plan + Propose）。**最坏路径**：3 次（Plan + Propose × 2，含一次回退）。Graph 计数器强制上限，不存在无限循环。

**理由**：纯 ReAct 让 LLM 在每步都重新决策路由，而本系统大多数步骤是固定的（读完就要生成提案，提案完就要等用户）。纯固定流水线又无法处理"第一次 Gather 信息不够"的边缘情况。固定骨架 + 有限回退在确定性和灵活性之间取得正确平衡：LLM 决策内容，Graph 决策结构。

**放弃纯 ReAct 的原因**：ReAct 让 LLM 在每步选"下一步去哪"，大多数步骤实际上是固定的，这是不必要的 token 消耗和不确定性来源；现代模型（2025+）工具调用准确率足够高，不需要迭代试错来弥补能力不足。

---

### 决策 4：资料追踪双模式 — sequential / pool

**选择**：`resources.tracking_mode` 区分两类资料：
- `sequential`：每个 unit 独立记录（视频系列、教程 repo），任务关联具体 unit_id
- `pool`：只追踪总数（力扣题目），任务关联 resource_id，target_count 表示今日做几题

**理由**：力扣不需要为100道题各建一行 unit，但灵茶山每讲都是独立内容需要精确追踪。统一 schema 但用 tracking_mode 分支处理，接口对外一致。

---

### 决策 5：Morning Agent 触发 — Swift spawn（Option B + 端口检测）

> **[实施后修订 2026-05-08]** 原设计选 Option C（双 LaunchAgent），实施后评估认为 LaunchAgent 在高频开发期间干扰严重（KeepAlive 会不断重启被 kill 的进程），且生产期桌宠基本常开，Option B 已足够。改为 Option B 并加端口检测。

**当前实现**：`MalDaze/LearningAssistant/BackendProcessManager.swift`
- `applicationDidFinishLaunching` 时：TCP 探测 127.0.0.1:8765（0.5s 超时）
  - 端口已占用（手动 uvicorn 开发模式）→ 不介入，退出时也不 kill
  - 端口空闲 → spawn `.venv/bin/uvicorn`，退出时 kill
- Morning Agent 定时触发：APScheduler 在后端进程内每天 8:00 执行，同时后端启动时检查 events 表补触发当日漏跑的 briefing

> **[Bug 修复 2026-05-09]** 冷启动后桌宠一直显示"助手离线"，原因两个：
>
> 1. **路径发现失效**：`findBackendDir()` 通过 .app 同级目录向上搜索 6 层，但 Xcode 把 .app 放在 `DerivedData/.../Debug/`，6 层只能走到 `Xcode/`，永远到不了项目根 `/Users/cpt/Public/MalDaze/`，导致 `findBackendDir()` 返回 `nil`，后端从未启动。**修复**：新增层 2，读取 `DerivedData/<Name>-<hash>/info.plist` 中的 `WorkspacePath` 字段，取其父目录作为项目根，再拼接 `assistant_backend/`。开发期下可靠定位。
>
> 2. **启动竞态**：ViewModel 在 `init()` 里立即请求后端，而 uvicorn 需要数秒（冷启动可达 15s）才能就绪，导致 `ECONNREFUSED → isOffline = true`，且无自动重试。**修复**：spawn 后轮询端口（每 1s，最多 30s），就绪后发 `backendDidBecomeReady` 通知；ViewModel 收到通知再首次 fetch，期间显示"后端启动中…"。

**理由**：生产期桌宠基本常开（开机自启），后端生命周期与桌宠绑定足够可靠。端口检测解决了开发期手动 uvicorn 与桌宠并存的冲突问题。

**原 Option C 脚本保留**（`scripts/com.maldaze.backend.plist` 等）但不安装，作备选。

**备选方案放弃原因**：
- Option A（单 LaunchAgent 兼管两件事）：morning call 时机难以精确，需要轮询等 FastAPI 就绪
- Option C（双 LaunchAgent）：开发期 KeepAlive 与手动开发服务器冲突，需频繁 launchctl unload/load
- Swift AppDelegate 无端口检测：开发时手动 uvicorn 与 App spawn 冲突，导致端口占用报错

---

### 决策 6：Weekly Review 离线补偿 — events 表查询，不使用 flag

**选择**：APScheduler 于周日 20:00 尝试触发。若后端未运行（APScheduler 不在），不写任何 flag——因为 APScheduler 进程本身不存在，无法执行写入。离线补偿改由 Morning Agent 主动检测：每次启动时查询 events 表，若上周日（最近一个周日日期）不存在 `event_type = 'weekly_review_done'` 记录，则优先执行 Weekly Review 子图再继续今日流程。

**理由**：APScheduler 运行在 FastAPI 进程内，后端离线时它无法执行任何操作，写 flag 的逻辑本身就不可能运行。以 events 表作为真相来源更正确：`weekly_review_done` 存在 = 复盘已完成，不存在 = 需要补触发。这个机制同时处理了"后端离线"和"用户取消复盘"两种情况。

---

### 决策 7：每日无"跳过"按钮，未完成任务次日自动重排

**选择**：Morning Agent 每天检查前一天 `completed_at IS NULL` 的任务，将其 `scheduled_date` 更新为今天或最近可容纳的日期，`reschedule_count + 1`。不提供显式"状态不好"或"跳过"按钮。

**理由**：用户明确表示不希望有消极心理暗示；系统通过 `reschedule_count` 和完成时间戳被动感知节奏，在 Weekly Review 时给出调整建议。自然语言表达（"我想摆了"）走 Conversational Planner。

---

### 决策 8：Material Ingestion — Dispatcher + Handler + 归一化中间格式

**选择**：
```
Resource Dispatcher（识别类型）
├── github.com/*   → GitHub Handler
├── bilibili.com/* → Bilibili Handler（处理单 P / 分 P / 合集三种情况）
├── juejin.cn/*    → 掘金 Handler
├── *.pdf          → PDF Handler
└── 其他 URL       → Generic Scraper

所有 Handler 输出统一格式：
{
  title, type, tracking_mode,
  units: [{title, order_index, estimated_minutes}],
  total_estimated_hours
}
```

Scheduling Agent 只消费归一化格式，不关心来源。新增资料类型只需实现新 Handler。

**工时估算**（方案 B+C）：LLM 基于结构和内容估算基准工时，乘以 `resource.speed_factor`（用户首次使用时设置，后续可手动调整）。方案 D（自适应校准）列入后期优化。

## Risks / Trade-offs

**[风险] LLM 工时估算不准** → Mitigation：通过 `speed_factor` 让用户在 Ingestion 审核时直接调整；前几次使用后用户会建立对系统估算偏差的感知。

**[风险] Bilibili API 不稳定或结构变化** → Mitigation：Handler 内做防御性解析，API 失败时 fallback 到页面 HTML 抓取；合集探测失败降级为单视频处理。

**[风险] plan.md 被并发写入导致冲突** → Mitigation：后端写 plan.md 前加文件锁；单用户场景下实际并发概率极低。

**[风险] Morning Agent LaunchAgent 注册需要用户手动操作** → Mitigation：首次启动 MalDaze 时弹出引导，提供一键脚本注册 LaunchAgent。

**[Trade-off] 无"跳过"按钮** → 用户必须通过自然语言表达轻负荷意图；Conversational Planner 需要足够灵敏地识别"摆了"类意图，否则体验退化。

**[Trade-off] 每日重排而非每周** → 每天开机都会触发 LLM 调用（Morning Agent），有少量 API 成本；但换来的是计划始终反映最新状态。

## Open Questions

1. MalDaze Swift 侧三栏布局的具体比例（是否固定宽度还是可拖动）？
2. Ingestion 审核界面：草稿以什么形式展示给用户（表格 / 分天列表 / Markdown）？
3. `speed_factor` 首次设置：直接给一个滑块，还是让用户先做一个"校准任务"后自动推算？
4. 后端服务是否需要开机自启（除 LaunchAgent 触发单次外，FastAPI 进程是否常驻）？
