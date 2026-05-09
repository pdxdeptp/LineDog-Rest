# 学习助手 — 新用户验收场景清单

> 适用对象：从零开始的新用户（空数据库、无历史数据）
> 执行顺序：阶段 0 → 1 → 2 → 3 → 4 → 5（前一阶段通过后才进入下一阶段）

---

## 阶段 0：前提条件

| # | 检查项 | 期望结果 |
|---|--------|----------|
| 0-1 | 删除 `learning.db`，重新启动后端 | 后端自动创建空数据库，不报错，`GET /health` 返回 200 |
| 0-2 | 删除 `plan.md`，重新启动后端 | 后端启动正常，plan.md 缺失不影响健康检查 |
| 0-3 | 打开桌宠面板中栏 | 显示空状态提示，不崩溃，不白屏 |

---

## 阶段 1：添加第一个学习资料（Ingestion Agent）

测试链接：
- Bilibili: `https://www.bilibili.com/video/BV1bP411c7oJ/`
- GitHub: `https://github.com/shareAI-lab/learn-claude-code`

| # | 场景 | 输入 | 期望结果 |
|---|------|------|----------|
| 1-1a | Bilibili 资料分析 | POST /api/ingest 传入 Bilibili URL + deadline | 返回草稿：资料名 + 章节/分P列表 + 每集预估时长 |
| 1-1b | GitHub 资料分析 | POST /api/ingest 传入 GitHub URL + deadline | 返回草稿：repo 名 + 章节结构 + 预估工时 |
| 1-2 | 确认草稿写入 | POST /api/ingest/confirm 传入草稿 ID | DB 写入 resources / units / tasks，返回成功 |
| 1-3 | 取消草稿 | 不调用 confirm，直接抛弃草稿 | DB 无写入（查询 resources 表为空） |
| 1-4 | 无效 URL 兜底 | POST /api/ingest 传入 `https://invalid.example.com` | 返回错误信息，HTTP 状态码 4xx/5xx，不崩溃 |

---

## 阶段 2：Morning Agent（首次触发）

> 前提：阶段 1 的 1-2 已通过（DB 中有 tasks）

| # | 场景 | 操作 | 期望结果 |
|---|------|------|----------|
| 2-1 | 手动触发晨报 | POST /api/morning-briefing | 返回今日任务摘要 JSON，包含任务列表 |
| 2-2 | 空数据库时触发 | 清空 DB 后 POST /api/morning-briefing | 返回空摘要或提示语，不报错不崩溃 |
| 2-3 | 面板任务显示 | GET /api/today-briefing | 返回与 2-1 一致的任务数据 |
| 2-4 | 重复触发幂等 | 连续两次 POST /api/morning-briefing | 第二次返回与第一次相同内容，不重新生成 |

---

## 阶段 3：任务完成标记

> 前提：阶段 2 通过，知道至少一个 task_id

| # | 场景 | 操作 | 期望结果 |
|---|------|------|----------|
| 3-1 | 标记任务完成 | POST /api/tasks/{id}/complete | 返回 200，DB 中 completed_at 字段写入时间戳 |
| 3-2 | 重复标记 | 再次 POST /api/tasks/{id}/complete | 行为合理（幂等或返回已完成状态），不报错 |

---

## 阶段 4：Conversational Planner（对话）

> 前提：阶段 1-2 通过（DB 中有数据）

| # | 场景 | 输入 | 期望结果 |
|---|------|------|----------|
| 4-1 | 查询今日计划 | POST /api/chat {"message": "今天有什么任务"} | 返回今日任务摘要文本，不报错 |
| 4-2 | 减载请求 | POST /api/chat {"message": "今天不想学了"} | 返回减载提案（含变更摘要），包含 proposal 字段 |
| 4-3 | 确认变更 | POST /api/chat/confirm {"confirmed": true} | DB tasks 更新，返回成功 |
| 4-4 | 取消变更 | POST /api/chat/confirm {"confirmed": false} | DB 无变化，返回取消确认 |
| 4-5 | 空 DB 时对话 | 空数据库状态下 POST /api/chat {"message": "今天有什么任务"} | 返回合理的空状态回复，不报错 |

---

## 阶段 5：离线降级

> 与数据无关，可随时测

| # | 场景 | 操作 | 期望结果 |
|---|------|------|----------|
| 5-1 | 后端未启动时请求 | 关闭后端后 GET /health（或任意端点） | 连接被拒绝；前端中栏显示"助手离线"，不崩溃 |
| 5-2 | 后端启动后恢复 | 启动后端后 GET /health | 返回 200，面板恢复正常 |

---

## 执行规则

- 发现一个失败 → 停止 → 记录 → 修复 → 重新验证后继续
- 每条结果记录在 `acceptance-results.md`
- 所有 curl 命令输出原文附在结果 MD 中（不总结，不推断）
