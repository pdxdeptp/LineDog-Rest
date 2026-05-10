## Why

添加学习资料是学习助手的核心入口，但当前实现存在三个关键缺陷：分析过程是不透明的黑盒（用户只看到单一 spinner）、草稿展示过薄（用户无法在确认前审查完整排期或调整参数）、排期算法的默认行为不合理（默认每日容量 300 分钟导致大量任务挤在同一天，且无全局设置入口）。本轮将这个流程产品化为可信、可检查、可撤销的体验。

## What Changes

**后端**
- 将 `POST /api/ingest` 拆分为两段：`POST /api/ingest/start`（立即返回 thread_id）+ `GET /api/ingest/progress/{thread_id}`（SSE 流，实时推送分析阶段事件）
- 新增 `POST /api/ingest/reschedule`：接收 `thread_id + 新 deadline + 新 speed_factor`，仅重跑 `check_capacity`，返回新 `option_a / option_b`，不重新解析 URL
- `daily_capacity_min` 默认值从 300 改为 60（每日 1 小时）
- `ingestion_agent.py` 各组件的回退值统一为 60，消除三处不一致

**前端（IngestionView / LearningAssistantViewModel）**
- 分析阶段显示四个实时阶段标签（SSE 驱动）
- 草稿卡片新增"查看完整计划"按钮，打开只读弹窗，展示每日任务安排（可滚动）
- 方案选择器从 "A/B" 重命名为 "尽快学完 / 均匀铺开"，默认选中"均匀铺开"
- 修复选择器按钮不可点击问题（`.contentShape(Rectangle())`）
- 草稿卡片内支持调整 deadline 和 speed_factor，调整后 debounce 500ms 自动重新排期（就地刷新）
- 取消草稿后 URL 文本保留在输入框

**新增全局设置页**
- 新增"学习偏好"设置视图，支持查看和修改 `daily_capacity_min`（每日学习容量）
- Ingestion 草稿卡片内显示当前每日容量（只读），提供跳转设置入口

## Capabilities

### New Capabilities

- `ingestion-progress-sse`：基于 SSE 的添加资料实时进度推送，包含后端 event stream 端点和 Swift SSE 解析
- `learning-preferences`：全局学习偏好设置页，管理 `daily_capacity_min` 等系统级学习参数

### Modified Capabilities

- `material-ingestion`：API 协议从同步单请求改为 start + SSE 流 + confirm 三段；新增 reschedule 端点；草稿 UI 增加完整计划弹窗和参数调整；方案命名和默认值变更；修复三处 bug
- `assistant-panel-ui`：添加学习偏好设置入口（底部导航或设置按钮）

## Impact

**后端文件**
- `assistant_backend/src/routers/ingest.py`：重写端点，新增 SSE 端点和 reschedule 端点
- `assistant_backend/src/agents/ingestion_agent.py`：重构支持后台 task 运行 + 进度 emit；修复默认回退值
- `assistant_backend/src/db/schema.py`：`daily_capacity_min` 默认值改为 60

**前端文件**
- `MalDaze/LearningAssistant/IngestionView.swift`：全面重写（SSE 进度、草稿弹窗、参数调整）
- `MalDaze/LearningAssistant/LearningAssistantViewModel.swift`：新增 SSE 读取逻辑、reschedule 调用、selectedOption 默认值
- `MalDaze/LearningAssistant/AssistantAPIClient.swift`：新增 SSE 端点、reschedule 端点、learning preferences API
- `MalDaze/LearningAssistant/AssistantPanelView.swift`：新增学习偏好设置入口
- `MalDaze/LearningAssistant/LearningPreferencesView.swift`：新建全局设置视图

**测试文件**
- `assistant_backend/tests/test_integration.py`：更新 ingest 测试，新增 reschedule、SSE、learning preferences 场景
- `MalDazeTests/LearningAssistantTests.swift`：更新 ViewModel 测试

**Non-Goals（本轮不做）**
- 学习时长估算精准化（视频观看时长 ≠ 实际学习时长，如力扣视频需要额外练习时间）——已知问题，后续单独处理
- 新增 URL 类型支持（当前：GitHub / Bilibili / PDF / WebHandler 兜底）
- 草稿弹窗内逐集编辑预计时长
- SSE 断线后自动重连——中断只提示用户重新提交，不自动恢复
- 不同 error 类型展示不同 CTA——所有分析失败统一显示"请检查链接后重试"
- 取消草稿调用后端——取消是纯前端操作，不发 HTTP 请求
- 返回设置页后自动重新排期——返回草稿时不触发 reschedule，用户需主动修改参数
- 设置页扩展其他偏好字段——本轮只管 `daily_capacity_min`
