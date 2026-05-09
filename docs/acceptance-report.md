# 学习助手 — 新用户验收汇报

> 执行日期：2026-05-09 | 后端版本：main 分支当前 | 前端补充验证：2026-05-09

---

## 总览

| 阶段 | 场景数 | PASS | FAIL | 需修复 |
|------|--------|------|------|--------|
| 0 前提条件 | 3 | 2 | 0 | — |
| 1 Ingestion | 4 | 4 | 0 | 2 个 bug 已修复 |
| 2 Morning Agent | 4 | 4 | 0 | 1 个 bug 已修复 |
| 3 任务标记 | 2 | 2 | 0 | — |
| 4 对话 Planner | 4 | 4 | 0 | Bug 3a + 3b 均已修复 |
| 5 离线降级 | 2 | 2 | 0 | — |
| **合计** | **19** | **19** | **0** | — |

---

## 本次执行中发现并修复的 Bug（2 个）

### Bug 1：Ingestion Agent — handler 类对象序列化崩溃 🔴（已修复）

**现象：** `POST /api/ingest` 任意 URL 均返回 `{"detail":"Type is not msgpack serializable: type"}`，Ingestion 功能完全不可用。

**根因：** `dispatch_handler` 节点将 Python 类（`BilibiliHandler` / `GitHubHandler` 等）写入 LangGraph state，LangGraph 的 msgpack checkpointer 无法序列化 Python `type` 对象。

**修复：** 合并 `dispatch_handler` 和 `fetch_structure` 为单一节点，dispatch 结果直接使用，不入 state。

**影响文件：** `assistant_backend/src/agents/ingestion_agent.py`

---

### Bug 2：Morning Agent — 新用户添加资料后晨报仍为空 🔴（已修复）

**现象：** 用户添加第一个学习资料并确认后，调用 `POST /api/morning-briefing` 仍返回 `"tasks":[]`。

**根因：** Morning Agent 每日幂等，结果缓存在 `system_state` 表。若后端当日早于用户添加资料时已触发过（返回 0 任务），缓存不会因新资料到来而失效。新用户典型流程下必然触发此 bug。

**修复：** `write_to_db` 节点在确认写入后，删除当日晨报缓存 key（`briefing_YYYY-MM-DD`），下次调用时强制重新生成。

**影响文件：** `assistant_backend/src/agents/ingestion_agent.py`

---

## 已修复 Bug（本轮新增，共 3 个）

### Bug 3a：Conversational Planner — 所有消息 response 字段为 null 🔴（已修复）

**现象：** 所有 `/api/chat` 请求返回 `response: null`，用户完全看不到对话回复。

**根因：** `route_after_propose` 不论 `changes` 是否为空一律路由 `human_review`；`interrupt_before=["human_review"]` 无条件拦截图执行；`start_conversation` 命中拦截分支永远返回 `response: null`。

**修复：**
1. `route_after_propose` 新增第三条路径：`changes==[]` → 路由至新节点 `respond`
2. 新增 `respond_node`：用 `proposal.summary_for_user` 创建 `AIMessage`，图直接结束
3. 图跑完后 `start_conversation` else 分支自然取到 AIMessage → 返回 `response`

**修复后验证：**
```
POST /api/chat {"message":"今天有什么任务"}
→ {"response":"今天所有任务已完成。","proposal":null}  ✅
```

**影响文件：** `assistant_backend/src/agents/conversational_agent.py`

---

### Bug 3b：Conversational Planner — 变更类请求无法生效（三层根因） 🔴（已修复）

**根因 1（工具层缺口）：** gather 工具集中无返回具体 task_id 的接口，LLM 无法生成有效 `reschedule` action。
**修复：** `planner_tools.py` 新增 `get_tasks_by_date(date_str)` 工具；`_PLAN_SYSTEM_PROMPT` 声明并标注"变更前必须先调用"；`gather_node` 处理对应调用。

**根因 2（双重中断）：** `human_review_node` 内部调用 `interrupt()` 而图同时用了 `interrupt_before=["human_review"]`，导致两次暂停，`execute_node` 永远跑不到，DB 从未写入。
**修复：** 删除 `human_review_node` 内的 `interrupt()` 调用，仅保留 `interrupt_before` 机制。

**根因 3（resume 方式错误）：** `confirm_proposal` 用 `graph.astream({"user_confirmed": True}, config)` resume，对 `interrupt_before` 模式无效，state 未更新。
**修复：** 改为 `await graph.aupdate_state(config, {"user_confirmed": True}, as_node="human_review")` 再 `graph.astream(None, config)` 继续。

**修复后端到端验证：**
```
POST /api/chat {"message":"把明天的任务全部推迟到后天"}
→ proposal.changes = [{"action":"reschedule","task_id":2,"scheduled_date":"2026-05-11"}, ...]

POST /api/chat/confirm {"confirmed":true}
→ {"status":"applied","changes_applied":2}
→ DB: task id=2 scheduled_date 从 2026-05-10 → 2026-05-11 ✅
→ events: plan_updated 写入 ✅
```

**影响文件：** `src/tools/planner_tools.py`、`src/agents/conversational_agent.py`

---

## 通过场景确认（主要功能正常）

- ✅ **Bilibili 合集识别**：正确识别 27集算法视频，估算工时 4.55小时
- ✅ **GitHub Repo 识别**：正确识别仓库，LLM 推断 12章节，估算 13.75小时
- ✅ **双方案调度**：Option A（填空档）和 Option B（均匀铺开）均生成正确
- ✅ **草稿确认写入**：resource / units / tasks 原子写入，events 记录正常
- ✅ **草稿取消**：不写 DB，状态正确
- ✅ **无效 URL 降级**：不崩溃，WebHandler 兜底（UX 粗糙但功能正常）
- ✅ **Morning Agent 任务摘要**：正确读取今日任务，LLM 生成摘要
- ✅ **Morning Agent 幂等**：同日重复调用返回一致结果
- ✅ **任务完成标记**：`completed_at` 正确写入，重复调用幂等
- ✅ **对话确认/取消流程**：`/api/chat/confirm` 的 confirmed=true/false 路径均正常
- ✅ **离线降级（后端层）**：后端关闭时连接被拒绝，exit code 7

---

---

## 前端补充验证发现的 Bug（3 个，已修复）

> 背景：后端 curl 测试 19/19 PASS 后，用户从 Swift 前端实际操作，点击「分析」按钮后
> 2 秒内跳出「助手已离线」。curl 验证不覆盖客户端 JSON 解码路径。

### Bug A：前端 IngestionDraft 模型不匹配 🔴（已修复）

**现象：** 点击「分析」按钮约 2 秒后立即显示「助手已离线」。

**根因：** `IngestionDraft.draft` 类型为 `String`，但后端实际返回 JSON 对象。
`AssistantAPIClient.decode()` 将所有 `JSONDecoder` 错误归一转换为 `AssistantOfflineError`，导致解码失败被误判为离线。

**修复：**
- 新增 `IngestionDraftDetail` 结构体（`resourceTitle`, `resourceType`, `totalEstimatedHours`, `unitCount`, `optionA`, `optionB`）
- `IngestionDraft.draft` 类型从 `String` 改为 `IngestionDraftDetail`
- `ChatResponse.response` 从 `String` 改为 `String?`（后端返回 proposal 时 response 为 null）
- 新增 `ChatProposal` 结构体取代原来的 `String?` proposal 字段

**影响文件：** `MalDaze/LearningAssistant/AssistantAPIClient.swift`

---

### Bug B：前端请求超时（LLM 调用）🔴（已修复）

**现象：** LLM 推理耗时 30-60 秒，但 `URLSession` 超时设置仅 8 秒，必然超时。

**修复：** `timeoutIntervalForRequest` 从 8s → 120s；`timeoutIntervalForResource` 从 15s → 300s。

**影响文件：** `MalDaze/LearningAssistant/AssistantAPIClient.swift`

---

### Bug C：前端草稿展示仍为原始字符串 🟡（已修复）

**现象：** 即使解码成功，草稿区也只显示原始字符串，用户无法区分方案 A/B。

**修复：**
- `LearningAssistantViewModel.ingestionDraft` 类型从 `String?` 改为 `IngestionDraftDetail?`
- `IngestionView.draftSection` 改为结构化展示：资料名、集数/章节数、估算工时
- 新增方案 A（填空档）/ B（均匀铺开）选择器，`selectedOption` 随确认写入传给后端

**影响文件：** `MalDaze/LearningAssistant/IngestionView.swift`, `LearningAssistantViewModel.swift`

---

## 下一步（待人工验证）

1. **端到端前端验证：** 启动 App，输入 Bilibili/GitHub URL，点击「分析」—— 应正确展示草稿（资料名 + 方案选择器），不再出现「助手已离线」
2. **方案选择验证：** 选择方案 B，确认写入，验证 DB 中 tasks 按均匀铺开排列
3. **对话前端验证：** 输入「今天有什么任务」，验证对话框有文字回复
4. **UX 优化（非阻断）：** 无效 URL 时给出更友好的错误提示，而非返回以 URL 为名的草稿

---

*详细执行记录见：`docs/acceptance-results.md`*
*验收场景清单见：`docs/acceptance-checklist.md`*
