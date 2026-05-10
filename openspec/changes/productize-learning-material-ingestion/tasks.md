> 并行规则：后端 A 和后端 B 可并行；前端 A 和前端 B 在后端完成后可并行；测试在前后端均完成后运行。

## 1. 后端 A：SSE 基础设施 + ingestion API 重构

- [x] 1.1 在 `schema.py` 将 `daily_capacity_min` 默认值从 300 改为 60；将 `ingestion_agent.py`、`planner_tools.py`、`weekly_review_agent.py` 的回退值统一为 60；在应用启动初始化时执行一次性迁移：若 `system_state` 中 `daily_capacity_min` 值精确为 `"300"`（旧默认值），则更新为 `"60"`
- [x] 1.2 在 `ingestion_agent.py` 新增内存进度存储 `progress_store: dict[str, asyncio.Queue]`；将 `ingestion_graph.ainvoke` 改为 `asyncio.create_task` 后台运行；各节点完成后向队列 push 事件
- [x] 1.3 在 `routers/ingest.py` 新增 `POST /api/ingest/start`：接收 `url`、`deadline`、`speed_factor`，启动后台 task，立即返回 `{thread_id}`；同时删除旧 `POST /api/ingest` 同步端点；更新 `assistant_backend/tests/test_integration.py` 中所有对旧 `/api/ingest` 的直接调用，改为新的 start + SSE 流
- [x] 1.4 在 `routers/ingest.py` 新增 `GET /api/ingest/progress/{thread_id}`：SSE 端点，用 `fastapi.responses.StreamingResponse` 逐条 yield 事件（`event: phase\ndata: {...}\n\n`）；收到 `done: true` 后关闭流
- [x] 1.5 在 `routers/ingest.py` 新增 `POST /api/ingest/reschedule`：从 LangGraph checkpointer 读取 `resource`，用新 `deadline`/`speed_factor` 重跑 `_schedule_option_a`/`_schedule_option_b`，返回新 `option_a`/`option_b`，不推进 graph；thread 不存在时返回 `HTTP 404 {"error": "thread_not_found"}`（`/api/ingest/confirm` 同样处理）
- [x] 1.6 修改 `POST /api/ingest/confirm`（`ConfirmRequest`）：新增可选字段 `deadline: str | None` 和 `speed_factor: float | None`；`write_to_db` 优先使用请求中的值
- [x] 1.7 写失败测试后实现：`test_ingest_start_returns_thread_id`、`test_sse_phases_sequence`、`test_reschedule_returns_new_options`、`test_confirm_with_deadline_override`、`test_daily_capacity_default_is_60`

## 2. 后端 B：学习偏好 API

- [x] 2.1 新建 `routers/settings.py`，注册 `GET /api/settings/learning-preferences`：从 `system_state` 读取 `daily_capacity_min`，不存在时返回 60
- [x] 2.2 在 `routers/settings.py` 实现 `PUT /api/settings/learning-preferences`：校验 `daily_capacity_min` 范围 1–1440，写入 `system_state`
- [x] 2.3 在 `main.py` 注册 settings router
- [x] 2.4 写失败测试后实现：`test_get_learning_preferences_default`、`test_put_learning_preferences_valid`、`test_put_learning_preferences_invalid_range`

## 3. 前端 A：Ingestion SSE + 草稿重构（依赖后端 A）

- [x] 3.1 在 `AssistantAPIClient.swift` 新增 `startIngestion(url:deadline:speedFactor:) -> String`（调用 `/api/ingest/start`，返回 thread_id）
- [x] 3.2 在 `AssistantAPIClient.swift` 新增 `subscribeIngestionProgress(threadId:) -> AsyncStream<IngestionProgressEvent>`：用 `URLSession.bytes(for:)` 读取 SSE，解析 `data:` 行为 `IngestionProgressEvent`
- [x] 3.3 在 `AssistantAPIClient.swift` 新增 `rescheduleIngestion(threadId:deadline:speedFactor:) async throws -> IngestionDraftDetail`（调用 `/api/ingest/reschedule`）
- [x] 3.4 在 `AssistantAPIClient.swift` 修改 `confirmIngestion`：ConfirmRequest 新增可选 `deadline`/`speedFactor` 字段
- [x] 3.5 在 `LearningAssistantViewModel.swift` 将 `selectedOption` 默认值改为 `"B"`；重写 `startIngestion` 为两段：调 start → 订阅 SSE stream → 更新 `ingestionPhase`（新增 Published）→ 收到 draft_ready 后设 `ingestionDraft`；在 ViewModel 中新增 `private var analysisTask: Task<Void, Never>?`，`startIngestion` 将 SSE 订阅 Task 赋值给它；取消草稿和 `onDisappear` 时调用 `analysisTask?.cancel()`，防止 ViewModel 在视图消失后继续接收事件
- [x] 3.6 在 `LearningAssistantViewModel.swift` 新增 `reschedule(deadline:speedFactor:) async`：调 reschedule API，就地更新 `ingestionDraft`；`debounceReschedule()` 封装 500ms debounce 逻辑；追踪 `lastSyncedParams: (deadline, speedFactor)`（reschedule 成功时更新），并暴露 `canConfirm: Bool`（`currentParams == lastSyncedParams && !isRescheduling`）供 confirm 按钮绑定；reschedule/confirm 返回 `thread_not_found` 时清除草稿状态并设 `ingestionError = "session_expired"`
- [x] 3.7 重写 `IngestionView.swift`：进度区域显示四阶段标签（绑定 `vm.ingestionPhase`）；草稿卡片含可点击方案选择器（加 `.contentShape(Rectangle())`）、"查看完整计划"按钮、deadline DatePicker、speed Slider、每日容量只读显示 + "去设置 →"；`onAppear` 时 fetch 最新 daily_capacity_min 刷新容量显示；confirm 按钮绑定 `vm.canConfirm`（禁用时灰显无文字说明）；资源类型显示人类可读标签（映射表：`bilibili_series`→"B站合集"、`github`→"GitHub 仓库"、`pdf`→"PDF 文档"、其他→"网页"）；会话失效时显示"分析会话已失效，请重新提交链接"
- [x] 3.8 新建 `FullPlanSheetView.swift`：接收 `option_a` 或 `option_b` 数组和 `totalUnitCount`，顶部汇总行显示方案名称、总集数、总时长、截止日，并标注"全部 N 集已排入"或"X 集因容量不足未能排入"；列表展示日期 + 单元标题 + 分钟，可滚动；只读，无交互
- [x] 3.9 写 ViewModel 单元测试：`testSelectedOptionDefaultsToB`、`testRescheduleDebounce`、`testCancelPreservesURL`、`testSSEPhasesUpdateIngestionPhase`、`testCanConfirmFalseWhenParamsUnsynced`、`testCanConfirmTrueAfterSuccessfulReschedule`、`testSessionExpiredClearsDraft`

## 4. 前端 B：学习偏好设置页（依赖后端 B）

- [x] 4.1 在 `AssistantAPIClient.swift` 新增 `getLearningPreferences() async throws -> LearningPreferences` 和 `updateLearningPreferences(_:) async throws`
- [x] 4.2 新建 `LearningPreferencesView.swift`：显示当前 `daily_capacity_min`；Stepper 范围 15–480，步长 15；修改后调 PUT API；后端不可用时显示错误而非崩溃
- [x] 4.3 在 `AssistantPanelView.swift` 添加学习偏好入口（底部导航新增设置 Tab 或右上角齿轮图标），点击导航至 `LearningPreferencesView`

## 5. 集成验收

- [x] 5.1 运行 `pytest assistant_backend/tests/`，确认全部通过（包含 1.7、2.4 新增用例）
- [x] 5.2 运行 `xcodebuild test`，确认 Swift 测试全部通过（包含 3.9 新增用例）
- [ ] 5.3 手动验收：B站合集 27 视频 → SSE 四阶段正常 → 草稿显示"均匀铺开"为默认 → 弹窗展示 27 天排期 → 修改 deadline → 重新排期 → 确认写入 → 首页刷新
- [ ] 5.4 手动验收：无效 URL → error 事件 → 友好错误提示，URL 文本保留
- [ ] 5.5 手动验收：学习偏好设置页读取/修改 `daily_capacity_min`，Ingestion 草稿卡片显示正确值
- [ ] 5.6 手动验收：取消草稿 → URL 不丢失 → DB 无写入
