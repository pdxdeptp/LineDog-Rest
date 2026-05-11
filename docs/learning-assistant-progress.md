# 学习助手重修进度记录

> 对应路线图：`docs/learning-assistant-rework-roadmap.md`
> 更新原则：每个闭环完成归档后更新状态；重要决策或偏差记录在"备注"栏。
>
> ## 维护规则
>
> ### 状态定义
> | 状态 | 含义 |
> |------|------|
> | ⬜ 未开始 | roadmap 里有，还没碰 |
> | 🔄 进行中 | 正在 explore / propose / apply |
> | 🛑 阻断 | 因意外结果无法继续，详见闭环详情 |
> | ✅ 完成 | 归档完成，所有验收通过 |
> | ❌ 废弃 | 决定不做，但保留记录 |
>
> ### 阻断记录要求
> 当闭环因意外结果无法继续时，必须在闭环详情中记录：
> 1. **阻断原因**：具体是什么意外（不是"做不了"，是"为什么做不了"）
> 2. **已完成子任务**：哪些 tasks 完成了、哪些没完成
> 3. **未完成子任务**：剩余 work 的状态
> 4. **对后续闭环的影响**：后面的哪些闭环依赖这个、是否需要调整顺序
> 5. **恢复条件**：什么条件满足后可以重新打开
>
> ### 文档外产出记录
> 如果实现过程中产生了 propose 文档没覆盖的东西（accidentally 修了一个 bug、发现需要额外处理的 edge case、新增了 spec 没涵盖的行为），**必须在闭环详情中记录**。否则之后看文档会困惑"代码里有但文档里没有"。
>
> ### 更新时机
> - 每个闭环开始时 → 状态改为 🔄 进行中
> - 遇到阻断时 → 立即记录阻断详情
> - 闭环归档完成时 → 状态改为 ✅ 完成，填归档日期
> - 有新条目加入 backlog 时 → 在闭环详情备注
>
> ### 闭环详情模板
> 每个闭环的详情必须包含以下子节：
> - **完成内容 / 目标**
> - **测试结果**
> - **未完成项（非阻断）**
> - **关键决策**
> - **Deferred Decisions**：reviewer 标记为需要人类判断的问题（问题 + 默认选择 + 原因）
> - **Review Reports**：链接到 `openspec/changes/<change>/reviews/gate-*.md`

---

## 闭环总览

| # | change 名 | 阶段 | 状态 | 归档日期 |
|---|-----------|------|------|----------|
| 1 | `redesign-learning-assistant-home` | 第一阶段 | ✅ 完成 | 2026-05-10 |
| 2 | `productize-learning-material-ingestion` | 第一阶段 | ✅ 完成 | 2026-05-10 |
| 2.5 | `calibrate-unit-study-time-estimates` | 衔接二→三 | ⬜ 未开始 | — |
| 3 | `productize-today-learning-workbench` | 第二阶段 | ⬜ 未开始 | — |
| 4 | `productize-resource-progress-roadmap` | 第二阶段 | ⬜ 未开始 | — |
| 5 | `productize-conversational-planner-ui` | 第二阶段 | ⬜ 未开始 | — |
| 6 | `explain-morning-briefing-and-reschedule` | 第三阶段 | ⬜ 未开始 | — |
| 7 | `productize-weekly-review-experience` | 第三阶段 | ⬜ 未开始 | — |
| 8 | `clarify-assistant-backend-errors` | 第四阶段 | ⬜ 未开始 | — |
| 9 | `automate-learning-assistant-acceptance` | 第四阶段 | ⬜ 未开始 | — |

---

## 闭环详情

### ✅ 闭环一：学习助手首页 / 信息架构

**change:** `redesign-learning-assistant-home`
**归档路径:** `openspec/changes/archive/2026-05-10-redesign-learning-assistant-home/`

**完成内容**

- 宽屏 popover：`ControlPanelLayout` 从 `NSScreen.main?.visibleFrame` 计算宽度，左右栏固定，学习助手中栏自适应
- 首页 dashboard：summary-first 布局，替换原四 Tab 结构
- 底部固定导航：首页 / 添加资料 / 资料进度 / 调整计划，滚动时保持可见
- 今日任务列表：本地展示顺序（`UserDefaults` 持久化，不写后端 priority）
- 任务行展开：轻量详情 + 打开链接 / 链接不可用双状态
- 后端链接契约：`GET /api/today-briefing` 任务项新增 `resource_url` 和 `unit_url`
- 整栏离线状态：任何首页请求失败 → 整栏不可用，隐藏底部导航

**测试结果**

- `pytest`：9/9 passed
- `xcodebuild test`：TEST SUCCEEDED

**未完成项（非阻断）**

- 5.8：底部导航标签文字宽屏不重叠（已人工验证通过）
- 6.3：8 种视觉状态截图（已人工验证，未存档截图）

**关键决策**

- 不新增 dashboard summary API；前端组合 `/api/today-briefing` + `/api/resources`
- 任务展示顺序只存本地，不修改 Morning Agent 排期
- 离线不保留旧内容，整栏服务不可用替代缓存降级
- `NSPopover` 保持不变，通过 `contentSize` 实现宽屏

---

### ✅ 闭环二：添加学习资料

**change:** `productize-learning-material-ingestion`
**归档路径:** `openspec/changes/archive/2026-05-10-productize-learning-material-ingestion/`

**目标:** 让粘贴链接 → 系统理解 → 草稿展示 → 确认写入成为可信可检查可撤销的完整体验

**完成内容（摘要）**

- `POST /api/ingest/start` + SSE 进度、`/api/ingest/reschedule` / `confirm`、学习偏好 API、Swift 侧 ViewModel + Ingestion UI、单元测试与后端测试覆盖
- 无效 URL / 抓取失败走 SSE `error`；草稿侧每日容量随偏好 API 刷新并可触发重新排期

**后续愿望（未实现，记入路线图）**

- **首页今日任务条随学习偏好瞬时变化**：用户在设置里改 `daily_capacity_min` 后，希望**首页**依赖的今日简报（`/api/today-briefing` / Morning Agent / briefing 缓存）与任务展示也能尽快一致，而不只是「添加资料」草稿侧已同步。实现归属：首页跟进、`explain-morning-briefing-and-reschedule` 或单独窄 change；详见 `docs/learning-assistant-rework-roadmap.md` 闭环二小节「学习偏好与首页今日简报（跨闭环后续目标）」及闭环六探索项。

---

### ⬜ 闭环二点五：单元预计学习时长校准

**change:** `calibrate-unit-study-time-estimates`（建议名，以 OpenSpec 立项为准）
**阶段:** 衔接闭环二与闭环三（估时语义；详见路线图 §3.2.5）

**目标:** 视频 / 资料的原始时长 ≠ 学完所需时间；实操类（如力扣讲解）大头在课后做题，需在提交或草稿阶段让用户能校准「每单元预计分钟」，而不是仅靠解析结果。

**待探索问题**

- 解析完成后、确认写入前：是否增加向导步骤（按类型选倍数 / 模板），还是仅在草稿里允许逐项或批量改估时，或两者组合。
- 与 `reschedule`、confirm 契约如何扩展（每单元覆盖分钟、资料级系数等）。
- 类型启发（标题、用户标签）与默认策略的边界。

**状态:** ⬜ 未开始（路线图已收录问题陈述与验收方向）

---

### ⬜ 闭环三：今日学习工作台

**change:** `productize-today-learning-workbench`
**目标:** 把任务列表升级为当天学习工作台，支持实际用时记录和完成反馈

---

### ⬜ 闭环四：资料进度 / 学习路线图

**change:** `productize-resource-progress-roadmap`
**目标:** 把进度条列表升级为学习路线图，可见 deadline 风险和剩余量预测

---

### ⬜ 闭环五：对话式计划修改

**change:** `productize-conversational-planner-ui`
**目标:** 把聊天框改造为自然语言计划编辑器，proposal 展示结构化 diff

---

### ⬜ 闭环六：晨报 / 自动重排可解释性

**change:** `explain-morning-briefing-and-reschedule`
**目标:** 让用户理解 Morning Agent 为什么今天这样安排，尤其是自动重排和速度系数调整

---

### ⬜ 闭环七：周复盘

**change:** `productize-weekly-review-experience`
**目标:** 把后端 Weekly Review Agent 变成可被用户理解和确认的周复盘体验

---

### ⬜ 闭环八：后端运行可靠性 / 错误语义

**change:** `clarify-assistant-backend-errors`
**目标:** 把"助手离线"从万能错误改为清晰错误状态体系

---

### ⬜ 闭环九：验收自动化基础设施

**change:** `automate-learning-assistant-acceptance`
**目标:** 把人工验收清单升级为可重复运行的验收工具

---

## 当前状态

**活跃闭环:** 无（闭环一、闭环二已归档）

**下一步:** 优先对 **闭环二点五**（单元预计学时校准，路线图 §3.2.5）做 explore 并决定是否立项 OpenSpec；再启动闭环三 `productize-today-learning-workbench`。亦可并行筹备工作台，但估时应单独立项以免假设被放大。
