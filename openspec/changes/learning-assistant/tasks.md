## 1. 后端项目初始化

- [ ] 1.1 重建 `assistant_backend/` 目录结构：`src/agents/`、`src/routers/`、`src/tools/`、`src/db/`、`src/handlers/`
- [ ] 1.2 更新 `pyproject.toml`，确认依赖：fastapi、uvicorn、langgraph、langchain-google-genai、aiosqlite、apscheduler、python-dotenv
- [ ] 1.3 创建 `.env.example`，定义 `GEMINI_API_KEY`、`PLAN_MD_PATH`、`DB_PATH`、`PORT=8765`
- [ ] 1.4 创建 `src/main.py`：FastAPI app 实例、lifespan（启动时初始化 DB + APScheduler）、注册路由

## 2. 数据层（learning-data-layer spec）

- [ ] 2.1 实现 `src/db/schema.py`：所有 CREATE TABLE IF NOT EXISTS 语句（resources、units、tasks、plan_versions、events、system_state）
- [ ] 2.2 实现 `src/db/init.py`：首次启动时建表 + 写入默认 system_state 键值
- [ ] 2.3 实现 `src/db/queries.py`：常用查询函数（get_tasks_by_date、get_incomplete_yesterday、get_resource_progress、check_capacity、upsert_system_state 等）
- [ ] 2.4 实现 `src/db/plan_md.py`：read_plan_md()、write_plan_md()（含文件锁）、snapshot_to_db()

## 3. Material Ingestion Agent（material-ingestion spec）

- [ ] 3.1 实现 `src/handlers/dispatcher.py`：URL 类型识别函数，返回对应 Handler 类
- [ ] 3.2 实现 `src/handlers/github_handler.py`：GitHub API 调用（README + tree）、LLM 结构提取（优先级1→2→3）、输出 ResourceStructure
- [ ] 3.3 实现 `src/handlers/bilibili_handler.py`：单P / 分P / 合集三种形态检测，Bilibili API 调用，降级处理，输出 ResourceStructure
- [ ] 3.4 实现 `src/handlers/pdf_handler.py`：文本提取、章节识别、输出 ResourceStructure
- [ ] 3.5 实现 `src/handlers/web_handler.py`：通用页面抓取 + LLM 结构提取，输出 ResourceStructure
- [ ] 3.6 实现 `src/agents/ingestion_agent.py`：LangGraph graph（Dispatcher → Handler → LLM 估时 → Scheduler → interrupt → 写入），含 Option 3 冲突检测逻辑
- [ ] 3.7 实现 `src/routers/ingest.py`：`POST /api/ingest`（启动 graph，返回草稿）、`POST /api/ingest/confirm`（写入 DB）

## 4. Daily Morning Agent（daily-morning-agent spec）

- [ ] 4.1 实现 `src/agents/morning_agent.py`：LangGraph graph（检查 pending_weekly_review → 重排昨日未完成任务 → 生成今日摘要）
- [ ] 4.2 实现幂等检查：同一日历日内重复调用直接返回缓存摘要
- [ ] 4.3 实现重排逻辑：按 priority 填充今日 capacity，溢出任务顺延到最近空档，reschedule_count + 1
- [ ] 4.4 实现 `src/routers/morning.py`：`POST /api/morning-briefing`、`GET /api/today-briefing`
- [ ] 4.5 创建 macOS LaunchAgent plist 模板（`scripts/com.maldaze.morning-agent.plist`）和一键注册脚本（`scripts/install_launchagent.sh`）

## 5. Conversational Planner（conversational-planner spec）

- [ ] 5.1 实现 `src/tools/planner_tools.py`：8个工具函数（get_current_plan、get_task_stats、get_resource_progress、check_capacity、update_tasks、rewrite_plan、present_proposal、apply_confirmed_change）
- [ ] 5.2 实现 `src/agents/conversational_agent.py`：ReAct 风格 LangGraph graph，工具集绑定，interrupt 于 present_proposal 调用时
- [ ] 5.3 实现减载意图识别提示词（system prompt 中定义减载语义范围）
- [ ] 5.4 实现 `src/routers/chat.py`：`POST /api/chat`（启动/继续对话）、`POST /api/chat/confirm`（用户确认变更）

## 6. Weekly Review Agent（weekly-review-agent spec）

- [ ] 6.1 实现 `src/agents/weekly_review_agent.py`：LangGraph graph（聚合数据 → 减载判断 → 草稿生成 → interrupt → 写入）
- [ ] 6.2 实现数据聚合逻辑：本周完成率、资料工时对比、deadline 可行性校验、reschedule_count 分析
- [ ] 6.3 实现 APScheduler 任务：周日 20:00 触发 Weekly Review；失败时写入 pending_weekly_review=true
- [ ] 6.4 实现 `src/routers/review.py`：`POST /api/weekly-review/trigger`（手动触发）、`POST /api/weekly-review/confirm`（用户确认草稿）

## 7. MalDaze Swift 前端 — 三栏布局（assistant-panel-ui spec）

- [ ] 7.1 将现有面板从双栏布局重构为三栏（HStack），中间栏宽度固定或按比例分配
- [ ] 7.2 实现 `AssistantPanelView.swift`：今日任务列表视图（数据从 `/api/today-briefing` 拉取）
- [ ] 7.3 实现任务完成标记：点击 ✓ 按钮 → `POST /api/tasks/{id}/complete` → 即时更新 UI
- [ ] 7.4 实现资料进度视图（Tab 切换）：列出 active 资料及进度条
- [ ] 7.5 实现对话输入框：发送消息 → `POST /api/chat` → 展示回复气泡；变更提案展示含 [确认]/[取消] 按钮
- [ ] 7.6 实现 Ingestion 入口：URL 输入框 + deadline 选择 + 分析按钮 → 草稿展示 → 确认写入
- [ ] 7.7 实现后端离线降级：HTTP 请求失败时中栏显示"助手离线"，不影响其余功能
- [ ] 7.8 实现开机触发 LaunchAgent 的引导 UI（首次使用时提示用户运行安装脚本）

## 8. Speed Factor 自适应校准（方案 D 基础版）

- [ ] 8.1 在 `src/db/queries.py` 中实现 `get_resource_reschedule_stats(resource_id, days=14)`：返回该资料近期任务的 reschedule_rate 和 completion_rate
- [ ] 8.2 在 Morning Agent 中添加校准步骤：遍历所有 active 资料，对数据点 ≥ 5 的资料运行校准逻辑，更新 `resources.speed_factor`，写入 `speed_factor_changed` 事件
- [ ] 8.3 在 Weekly Review Agent 中添加：若本周有资料触发了 speed_factor 调整，在复盘摘要中告知用户（"灵茶山的实际完成速度比预估慢，已自动调整后续估算"）

## 9. 集成测试

- [ ] 8.1 端到端测试：粘贴 AgentGuide GitHub repo URL → 生成计划 → 确认 → 今日摘要包含对应任务
- [ ] 8.2 端到端测试：粘贴灵茶山 B站合集 URL → 合集视频列表识别正确 → 生成计划
- [ ] 8.3 端到端测试：对话"今天状态不好想摆了" → Conversational Planner 生成减载提案 → 确认 → load_mode=reduced
- [ ] 8.4 端到端测试：周日 20:00 Weekly Review 触发 → 草稿生成 → 用户确认 → tasks 表写入下周任务
- [ ] 8.5 离线补触发测试：模拟周日后端离线 → pending_weekly_review=true → 次日 Morning Agent 补触发
- [ ] 8.6 幂等测试：同日重复调用 `/api/morning-briefing` 不触发重复重排
