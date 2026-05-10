## Context

当前 `POST /api/ingest` 是同步阻塞请求：后端跑完 `fetch_structure → estimate_time → check_capacity → present_draft` 四个节点（10–30 秒）才返回。前端只有一个 spinner，用户无法感知进度。草稿仅展示总量（集数 + 总小时），不展示完整排期；方案选择器按钮因 `.buttonStyle(.plain)` hit-testing 问题无法点击；`daily_capacity_min` 默认 300 分钟，导致短视频资料全部落在今天。

## Goals / Non-Goals

**Goals:**
- 用户在分析过程中看到四个实时阶段（SSE 驱动）
- 用户能在确认前查看完整每日排期（只读弹窗）
- 用户能在确认前调整 deadline / speed_factor，调整后自动重新排期
- 默认选择"均匀铺开"（Option B），修复按钮失效 bug
- 全局学习偏好设置页，支持配置每日学习容量
- `daily_capacity_min` 默认值改为 60 分钟，各模块回退值统一

**Non-Goals:**
- 视频观看时长 ≠ 实际学习时长的精准建模（力扣类资料）
- 新增 URL 类型支持
- 草稿弹窗内逐集编辑预计时长

## Decisions

### D1：SSE vs 轮询

**选择：SSE（Server-Sent Events）**

架构改动：
```
旧：POST /api/ingest → 等待 10-30 秒 → 返回草稿

新：
  1. POST /api/ingest/start → 立即返回 {thread_id}
  2. GET  /api/ingest/progress/{thread_id}  （SSE 流）
       event: phase
       data: {"phase": "fetch_structure", "label": "正在读取章节结构…", "done": false}
       ...
       data: {"phase": "draft_ready", "draft": {...}, "done": true}
  3. POST /api/ingest/confirm（不变）
  4. POST /api/ingest/reschedule（新增）
```

后端实现：`/api/ingest/start` 用 `asyncio.create_task` 在后台异步运行，后台 task 内用 `ingestion_graph.astream(input, config)` 迭代节点输出——`astream()` 在每个节点完成后 yield 当前状态，后台 task 据此识别节点边界并向 `progress_store[thread_id]`（`asyncio.Queue`）push 对应阶段事件。SSE 端点从队列逐条读取并 yield 给客户端，直至收到终态事件（`done: true`）后关闭流。

**为何选 `astream()` 而非 `ainvoke()`：** `ainvoke()` 是黑盒，只在整图完成后才返回，无法在节点间注入进度事件。`astream()` 在每个节点完成后 yield 状态快照，后台 task 可按节点名称精确识别阶段并立即推送事件，无需修改 LangGraph 图内部结构。

Swift 侧用 `URLSession.bytes(for: request)` 逐行读取 SSE，解析 `data:` 行。

**拒绝的替代：轮询** —— 需要额外 status 端点 + 客户端定时器，整体代码量不减，SSE 延迟更低，与 FastAPI 的 `StreamingResponse` 原生集成更简洁。

### D2：reschedule 端点不重跑 LangGraph

**选择：独立调度函数，不依赖 LangGraph 状态**

`POST /api/ingest/reschedule` 实现：
1. 从 LangGraph checkpointer 读取 thread 的 `resource` 状态（已解析的资料结构）
2. 用新 deadline / speed_factor 直接调用 `check_capacity_node` 的调度逻辑
3. 返回新 `option_a / option_b`，不提交到 LangGraph（graph 仍停在 interrupt 点）
4. 用户最终 confirm 时，ConfirmRequest 额外携带 `deadline` 和 `speed_factor`，`write_to_db` 使用这些值

**拒绝的替代：用 `update_state` 修改 LangGraph 状态后重跑** —— LangGraph checkpoint API 在重跑部分节点时行为复杂，风险高于直接提取数据重算。

**并发一致性保证（前端）：** ViewModel 追踪 `lastSyncedParams: (deadline, speedFactor)`，在 reschedule 成功后更新。当 `currentParams != lastSyncedParams` 时，confirm 按钮保持禁用。这确保写入 DB 的排期始终与用户当前看到的参数一致。

**Thread 生命周期：** MemorySaver 无持久化，进程重启后 thread 丢失。reschedule 和 confirm 端点在 thread 不存在时返回 `HTTP 404 {"error": "thread_not_found"}`，前端识别此语义后清草稿并提示重新提交，不显示"稍后重试"。这与普通网络错误的处理路径明确区分。

### D3：草稿弹窗设计

完整计划弹窗（`FullPlanSheetView`）是只读的，方案选择留在主卡片：
```
主卡片
  ┌──────────────────────────────────────┐
  │ Swift 并发编程 · bilibili_series      │
  │ 18 集 · 9.0 小时                     │
  │ [尽快学完] [均匀铺开 ●]               │  ← 选择在这里
  │ [查看完整计划 →]                      │
  │ 截止日: [DatePicker]                  │
  │ 速度: [Slider 0.5×–2.0×]             │
  │ 每日容量: 60 分钟  [去设置 →]         │
  │ [确认写入]  [取消]                    │
  └──────────────────────────────────────┘

弹窗（只读）
  5月11日（周日）
    async/await 基础  30 分钟
  5月12日（周一）
    Task 与 TaskGroup  45 分钟
  …
```

### D4：daily_capacity_min 默认值和统一

- `schema.py` 默认值：300 → 60
- `ingestion_agent.py` 回退：60（与 `reduced_capacity_min` 默认值一致）
- `planner_tools.py` 回退：120 → 60
- `weekly_review_agent.py` 回退：300 → 60

全局学习偏好设置页（`LearningPreferencesView`）提供一个 Stepper / Slider 修改 `daily_capacity_min`，通过新 `GET/PUT /api/settings/learning-preferences` API 读写 `system_state`。

### D5：SSE 进度内存存储

`progress_store: dict[str, asyncio.Queue]` 存 thread_id → 事件队列，模块级单例。后台 task 完成或失败后推送终态事件，SSE 端点读完终态后关闭连接。不做持久化（进程重启后丢失，可接受，因为用户大概率已经在等待结果了）。

### D6：Subagent 分工边界

| Subagent | 文件边界 | 依赖 |
|---|---|---|
| 后端 A：SSE 基础设施 | `routers/ingest.py`、`agents/ingestion_agent.py`、`db/schema.py` | 无 |
| 后端 B：学习偏好 API | `routers/settings.py`（新建）、`db/queries.py` | 无 |
| 前端 A：Ingestion SSE + 草稿 | `IngestionView.swift`、`LearningAssistantViewModel.swift`、`AssistantAPIClient.swift` | 后端 A 完成后 |
| 前端 B：学习偏好设置页 | `LearningPreferencesView.swift`、`AssistantPanelView.swift` | 后端 B 完成后 |
| 测试与验收 | `test_integration.py`、`LearningAssistantTests.swift` | 前后端均完成后 |

后端 A 和后端 B 可并行。前端 A 和前端 B 在后端完成后可并行。

## Risks / Trade-offs

**[SSE 连接中断]** → 前端检测到流关闭时，如果尚未收到 `draft_ready`，显示"分析中断，请重试"并允许用户重新提交 URL（草稿无需保留）

**[后台 task 孤儿]** → 如果 SSE 连接在 `draft_ready` 前断开，后台 asyncio task 会继续跑到完成后自动清理，不会泄漏

**[LangGraph MemorySaver 重启丢失]** → 进程重启后 thread state 丢失，用户需要重新提交；这是当前架构的已有局限，本轮不解决

**[reschedule 与 confirm 之间的参数漂移]** → 用户调参后看到新排期，但如果等待很长时间再确认，confirm 请求必须携带最终使用的 deadline/speed_factor，而非依赖 LangGraph 内的旧值。ConfirmRequest 添加可选字段 `deadline` 和 `speed_factor`，`write_to_db` 节点优先使用请求中的值

**[`daily_capacity_min` 改为 60 影响已有用户]** → 下一次 Morning Agent 运行会读新值。已排期的任务不受影响（只影响后续 ingestion 和 reschedule）。可接受。

### D7：取消草稿为纯前端操作

**选择：取消不发 HTTP 请求，仅清除客户端状态**

`vm.ingestionDraft = nil` + `vm.ingestionThreadId = nil` 即完成取消。不调用 `POST /api/ingest/confirm?confirmed=false`。

LangGraph thread 在内存中自然存在，进程重启后丢失；MemorySaver 无持久化，不存在资源泄漏问题。取消操作本就不写 DB，后端无需感知。

**拒绝的替代：发 confirm(false) 通知后端** —— 引入不必要的网络依赖；取消本地操作不应失败，但网络请求可能超时，产生不合理的用户感知风险。

## Open Questions

_无阻断性未决问题。学习时长估算精准化（视频时长 vs 实际学习时长）显式排除为 Non-Goal，后续单独立 change 处理。_
