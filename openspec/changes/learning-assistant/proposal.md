## Why

准备七月中旬互联网秋招提前批（Agent 开发岗）需要在约十周内系统完成力扣、Agent 框架学习、八股文、简历打磨等多条线任务，普通 Todo 工具无法做到"读取一个 GitHub repo 就自动生成学习计划"、"开机自动重排昨日未完成任务"、"自然语言对话修改全局计划"这几件事。把这套智能规划能力直接做进已有的 MalDaze 桌宠，日常交互零额外入口。

## What Changes

- **新增** Python FastAPI 后端（从零构建，替换已删除的 assistant_backend 骨架）
- **新增** Material Ingestion Agent：输入任意学习资料 URL（GitHub repo / B站合集 / PDF / 掘金文章），自动解析结构、估算工时、生成每日任务草稿
- **新增** Morning Agent：每次开机触发，重排昨日未完成任务，生成当日摘要推送到 MalDaze
- **新增** Conversational Planner：自然语言对话修改计划（"我想摆了" / "把今天的八股换成项目时间" / "这章比预期难需要多一周"）
- **新增** Weekly Review Agent：每周日晚定时触发（含离线补触发机制），聚合数据、生成下周草稿、用户审核后写入
- **新增** SQLite 数据层：resources / units / tasks / plan_versions / events / system_state 六张表
- **新增** MalDaze 助手面板：现有左右两栏扩展为三栏，中间新增学习任务面板（Swift/SwiftUI）

## Capabilities

### New Capabilities

- `material-ingestion`: 多类型资料解析 + 工时估算 + 调度冲突检测 + 任务草稿生成，统一归一化中间格式
- `daily-morning-agent`: 开机触发 → 未完成任务重排 → 当日摘要生成 → 推送面板
- `conversational-planner`: ReAct 风格 LLM Agent，工具集驱动（非硬编码路由），处理任意自然语言规划意图
- `weekly-review-agent`: 定时触发 + 离线补偿 + 减载建议 + 人工审核 interrupt
- `learning-data-layer`: SQLite schema（含 sequential/pool 双模式资料追踪）+ plan.md 版本管理
- `assistant-panel-ui`: MalDaze 三栏布局 + 学习任务面板（任务列表、资料进度、对话入口）

### Modified Capabilities

## Impact

- **后端**：全新 Python 服务（FastAPI + LangGraph + aiosqlite + APScheduler + google-generativeai）
- **Swift 前端**：MalDaze 面板布局从两栏改为三栏，新增与 FastAPI 的 HTTP 通信层，新增开机触发逻辑
- **存储**：新增 `learning.db`（SQLite）和 `plan.md` 文件（战略文档，由 Agent 维护）
- **外部 API 依赖**：Gemini API（已有 key）、GitHub API（public，无需 token）、Bilibili API（public）
- **无破坏性变更**：现有提醒事项、番茄钟、智能输入功能不受影响
