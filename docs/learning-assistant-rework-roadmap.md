# 学习助手重修路线图

> 本文档记录学习助手后续重修的总工作流、闭环拆分、验收原则和建议顺序。它不是某个单独功能的 OpenSpec proposal，而是后续逐个创建 OpenSpec change 的依据。

## 0. 商定工作流

学习助手后续不再以“大功能一次生成”的方式推进，而是以“体验闭环”为单位逐个设计、实现、验收。

每个闭环使用以下流程：

```text
Explore
  ↓
OpenSpec proposal/spec/tasks
  ↓
用户审核文档
  ↓
opsx:apply
  ↓
分派 subagents
  ↓
每个 subagent 严格 TDD 实现
  ↓
前后端自动验收
  ↓
主 agent 汇总验收报告
  ↓
仅将无法自动判断的产品问题交还用户
```

### 0.1 用户参与边界

用户主要参与前半段：

- 说明这个闭环要解决的真实使用痛点。
- 判断什么体验是舒服的，什么体验是不可接受的。
- 确认信息层级、默认路径、文案口吻和产品取舍。
- 审核 `proposal.md`、`design.md`、`spec.md`、`tasks.md` 是否足够准确。

用户不应被迫参与后半段的低价值人工流程：

- 不应逐个手动找 bug。
- 不应反复把同一类细节喂给 agent 修。
- 不应承担 API/前端状态/数据一致性这类可自动验收问题。

### 0.2 Agent 执行边界

文档通过后，agent 后半段应自动完成：

- 按任务依赖关系拆分 subagent。
- 每个 subagent 只负责独立文件或独立子系统，避免并行冲突。
- 每个 subagent 必须先写失败测试，再写实现，再重构。
- 每个任务完成后做两阶段 review：spec compliance review 与 code quality review。
- 主 agent 负责集成、跑全局测试、生成验收报告。

### 0.3 每个 OpenSpec change 必须包含的内容

每个闭环的 OpenSpec 文档不能只写“要做什么”，还必须写清楚“怎么知道做对了”。

必须包含：

- Affected Specs：先运行 `openspec list --specs`，列出本 change 修改的主 spec id。
- 用户旅程：这个闭环从哪里开始，到哪里算完成。
- 状态矩阵：空状态、加载中、成功、失败、部分失败、离线、超时。
- 前端验收标准：布局、信息层级、按钮状态、错误提示、文案、截图场景。
- 后端契约：API 输入输出、错误语义、幂等性、字段含义。
- 测试 fixture：空数据库、有资料、有今日任务、有 proposal、错误响应等。
- Subagent handoff：前端、后端、测试、验收的分工和文件边界。
- 验收命令：`pytest`、`xcodebuild test`、curl 场景、必要时截图或 UI 状态检查。

### 0.3.1 Spec Targeting Gate

每个 change 在创建 `proposal.md`、`design.md`、`specs/`、`tasks.md` 之前，必须先确定目标主 spec。

固定步骤：

```text
1. 运行 openspec list --specs
2. 选择本 change 修改的已有 spec-id
3. 在 proposal.md 写 Affected Specs
4. 在 changes/<name>/specs/<spec-id>/spec.md 写 delta spec
5. 只有现有主 specs 没有对应能力时，才创建新的 spec-id
```

Archive 同步是路径驱动的：

```text
openspec/changes/<change-name>/specs/<spec-id>/spec.md
  ↓ archive
openspec/specs/<spec-id>/spec.md
```

因此不要依赖 change 名称的语义来决定归档目标。比如学习助手首页重设计应修改 `specs/assistant-panel-ui/spec.md`，而不是随手新建 `specs/learning-assistant-home/spec.md`，除非已经明确决定“首页”是一项新的长期 capability。

### 0.4 实施硬门槛

- 前半段必须先完成 OpenSpec proposal/spec/tasks。
- 文档没过，不进入实现。
- 创建 proposal 前必须通过 Spec Targeting Gate，明确 affected spec ids。
- 实现阶段不由主 agent 直接写主要业务代码，主 agent 负责调度、审查和集成。
- 每个实现任务遵守 TDD：失败测试先于实现代码。
- 前后端契约变化必须同步更新 spec。
- 验收报告必须列出自动验证通过项、未覆盖项、残余风险和需要用户判断的点。

## 1. 当前判断

学习助手目前是一版“能跑的功能原型”，不是完成产品化的体验。

现有能力已经覆盖很多系统层面：

- Python FastAPI 后端。
- SQLite 数据层。
- Material Ingestion Agent。
- Daily Morning Agent。
- Conversational Planner。
- Weekly Review Agent。
- SwiftUI 三栏学习助手面板。
- 基础前后端测试与验收记录。

但当前问题也很清晰：

- 旧 OpenSpec 一次塞入太多功能，导致每块都只是名义完成。
- 前端更像调试面板，而不是学习助手的日常工作台。
- UI 状态、文案、信息层级、错误恢复、提案展示都缺少产品化设计。
- 后端已有能力没有被前端解释成用户能理解的体验。
- 测试覆盖了很多模型和 ViewModel 逻辑，但 SwiftUI 视觉与端到端操作仍偏人工。

后续目标不是推倒重写，而是把现有原型按体验闭环逐个产品化。

## 2. 不纳入本轮重修范围

桌宠视觉、桌宠动画、喝水提醒等已经基本完成或属于其他 change，不纳入学习助手重修主线。

本路线图只关注：

- 学习助手中栏。
- 学习助手前端体验。
- 学习助手后端 API 和数据契约。
- 学习助手前后端验收自动化。

## 3. 建议闭环顺序

### 3.1 闭环一：学习助手首页 / 信息架构

建议 change 名：

```text
redesign-learning-assistant-home
```

目标：

把当前四个 Tab 堆叠的中栏，改造成真正的学习助手入口。用户打开面板时，应该立刻知道今天要做什么、当前状态如何、下一步该点哪里。

当前痛点：

- 默认 Tab 只是“今日任务”，缺少整体状态。
- “添加资料 / 对话 / 资料进度”被平铺成同级 Tab，缺少主次。
- 空状态、后端启动中、离线、错误提示都偏工程化。
- 首页没有承担“学习助手今天怎么看我”的角色。

需要探索：

- 默认首页是否仍保留 Tab，还是改成 dashboard + 次级入口。
- 今日任务、资料风险、添加资料、对话修改计划，哪个是一屏内最高优先级。
- 空数据库用户第一次打开时，应该被引导做什么。
- 有任务用户打开时，应该先看摘要还是先看任务。
- 离线和启动中状态是否应该阻断整个中栏，还是保留本地缓存内容。

前端重点：

- `AssistantPanelView.swift`
- 首页布局、空状态、loading、offline、error、refresh。
- 三栏面板中的中栏宽度与可读性。

后端重点：

- 可能需要一个 dashboard summary API，聚合今日任务、资料风险、最近事件。
- 如果不新增 API，也要明确前端如何组合现有 `/api/today-briefing` 与 `/api/resources`。

验收重点：

- 空数据库截图。
- 后端启动中截图。
- 后端离线截图。
- 有今日任务截图。
- 有资料但今日无任务截图。
- 有 deadline 风险截图。

### 3.2 闭环二：添加学习资料

建议 change 名：

```text
productize-learning-material-ingestion
```

目标：

让“粘贴资料链接 → 系统理解资料 → 生成计划草稿 → 用户确认写入”成为可信、可检查、可撤销的体验。

当前痛点：

- 草稿展示过薄，只显示资料名、章节数、总小时和方案 A/B。
- 用户不知道系统解析了哪些章节。
- 用户不知道估时是否靠谱。
- 用户不知道方案 A/B 对未来计划的具体影响。
- 无效 URL、慢请求、部分解析失败的体验粗糙。

需要探索：

- 分析前是否需要明确支持类型：GitHub、B站、PDF、网页。
- 分析中是否显示阶段：识别类型、读取结构、估算工时、生成排期。
- 草稿是否展示章节列表预览。
- 方案 A/B 的命名是否应从“填空档/均匀铺开”改成更自然的用户语言。
- 用户确认前是否允许调整 deadline、speed factor、方案。
- 取消草稿后是否保留输入内容。

前端重点：

- `IngestionView.swift`
- `LearningAssistantViewModel.swift`
- `AssistantAPIClient.swift`

后端重点：

- `/api/ingest`
- `/api/ingest/confirm`
- ingestion draft 的结构化字段。
- 错误语义：不支持 URL、解析失败、LLM 超时、网络失败。

验收重点：

- GitHub repo 成功分析。
- B站视频或合集成功分析。
- 无效 URL 的友好错误。
- LLM 慢请求时不误报离线。
- 取消草稿不写 DB。
- 确认草稿写入后首页/今日任务刷新。

### 3.3 闭环三：今日学习工作台

建议 change 名：

```text
productize-today-learning-workbench
```

目标：

把“今日任务列表”升级为当天学习的工作台，让用户知道今天学什么、为什么这么安排、完成后发生什么。

当前痛点：

- 任务行只显示标题、资料名、目标分钟和完成按钮。
- 完成任务无法记录实际用时。
- 用户不知道任务顺序和优先级含义。
- 完成后的反馈较弱。
- 未完成任务次日会自动重排，但当天界面没有解释这个规则。

需要探索：

- 今日任务是否需要分组：必须完成、可选推进、补昨天。
- 是否显示今日总负荷与用户 capacity 的关系。
- 完成任务时是否弹出实际耗时输入。
- 任务是否允许“开始学习”并联动番茄钟。
- 任务完成后是否触发轻量反馈或进度更新。
- 今日任务为空时，应该引导添加资料还是解释今天已完成。

前端重点：

- `TaskRowView.swift`
- `AssistantPanelView.swift`
- `LearningAssistantViewModel.swift`

后端重点：

- `/api/today-briefing`
- `/api/tasks/{id}/complete`
- 可能新增 actual_minutes 更清晰的前端输入契约。

验收重点：

- 有未完成任务。
- 全部任务完成。
- P1 任务与普通任务的视觉区别。
- 标记完成后本地刷新与 DB 一致。
- 重复完成操作幂等。
- 今日无任务时的合理空状态。

### 3.4 闭环四：资料进度 / 学习路线图

建议 change 名：

```text
productize-resource-progress-roadmap
```

目标：

把“资料进度条列表”升级为学习路线图。用户应该能看懂每个资料进展、剩余量、deadline 风险和卡住位置。

当前痛点：

- 资料进度只显示标题、进度条、投入时长、deadline。
- 没有解释当前速度能否赶上 deadline。
- 没有展示后续章节或最近任务。
- 没有标出反复拖延的资料。
- `reschedule_count`、`speed_factor` 等后端信号没有转化为前端洞察。

需要探索：

- 资料详情是否需要展开态。
- 是否显示“预计完成日期”和“按当前速度是否超期”。
- 是否显示最近 3 个待学 unit。
- 是否允许用户对资料调速、延期、暂停。
- pool 类型资料和 sequential 类型资料是否需要不同展示。

前端重点：

- `ResourceProgressView.swift`
- 可能新增 Resource detail view。

后端重点：

- `/api/resources`
- 可能新增 resource detail API，返回 units、remaining_minutes、risk level。

验收重点：

- active 资料。
- completed 资料。
- overdue 或 deadline 风险资料。
- sequential 资料。
- pool 资料。
- 资料为空状态。

### 3.5 闭环五：对话式计划修改

建议 change 名：

```text
productize-conversational-planner-ui
```

目标：

把普通聊天框改造成“自然语言计划编辑器”。用户不只看到回复，还要看懂提案会修改什么、影响什么、确认后会发生什么。

当前痛点：

- Proposal 只展示 `summaryForUser` 字符串。
- 不展示结构化 diff。
- 确认/取消按钮太简略。
- 用户无法清楚判断变更影响日期、任务、deadline。
- 错误时容易退化成“助手离线”。

需要探索：

- 聊天区是否仍作为独立 Tab，还是成为首页上的一个常驻输入。
- 提案卡片应展示任务级 diff 还是摘要 + 可展开详情。
- 哪些意图只回复文字，哪些意图必须出 proposal。
- 多轮追问时当前 proposal 如何保留或合并。
- 用户取消后是否解释“计划未改变”。

前端重点：

- `ChatView.swift`
- `LearningAssistantViewModel.swift`
- `AssistantAPIClient.swift`

后端重点：

- `/api/chat`
- `/api/chat/confirm`
- `ChatProposal` 结构从 summary 字符串升级为前端可渲染 diff。

验收重点：

- 查询今日任务，只返回文字。
- “今天不想学了”返回减载 proposal。
- “把明天任务推迟到后天”返回 reschedule diff。
- 确认后 DB 更新且今日任务刷新。
- 取消后 DB 不变。
- LLM 失败或 proposal malformed 时前端有合理错误。

### 3.6 闭环六：晨报 / 自动重排可解释性

建议 change 名：

```text
explain-morning-briefing-and-reschedule
```

目标：

让用户理解 Morning Agent 为什么今天这样安排，尤其是昨天没完成的任务如何被处理。

当前痛点：

- 后端有自动重排，但前端没有解释。
- 用户可能看到今天任务变化，却不知道原因。
- 今日摘要只是一段 highlights，不够结构化。
- 系统自动调整 speed_factor 或 load_mode 时缺少可见反馈。

需要探索：

- 晨报是否应该作为首页顶部卡片。
- 是否需要显示“昨日未完成 X 项，已顺延 Y 项”。
- 是否显示今日负荷状态：正常、偏重、减载。
- 是否把自动重排事件写成用户可读 timeline。
- 如果今天 briefing 还没生成，前端应该主动触发还是提示等待。

前端重点：

- 首页摘要区域。
- 今日任务区。
- 事件提示或小型 timeline。

后端重点：

- `morning_agent.py`
- `/api/today-briefing`
- `events` 表的可读化输出。

验收重点：

- 昨日有未完成任务。
- 今日 capacity 足够。
- 今日 capacity 不足，任务后推。
- 当日重复触发幂等。
- 空数据库时晨报不崩溃。

### 3.7 闭环七：周复盘

建议 change 名：

```text
productize-weekly-review-experience
```

目标：

把后端 Weekly Review Agent 变成可被用户理解和确认的周复盘体验。

当前痛点：

- 后端已有 weekly review router，但前端缺少完整界面。
- 下周草稿、减载建议、本周总结没有产品化入口。
- 用户无法编辑后确认。
- 周日离线补触发机制没有清晰可见反馈。

需要探索：

- 周复盘出现在哪里：首页提醒、单独入口、弹层还是 Tab。
- 本周总结展示哪些指标：完成率、拖延任务、资料风险、实际投入。
- 减载建议如何表达，避免让用户感觉被批评。
- 下周计划草稿是否允许逐日编辑。
- 用户关闭复盘后是否推迟、取消还是下次继续提醒。

前端重点：

- 可能新增 WeeklyReviewView。
- 首页提醒入口。
- proposal/confirm UI。

后端重点：

- `/api/weekly-review/trigger`
- `/api/weekly-review/draft/{thread_id}`
- `/api/weekly-review/confirm`

验收重点：

- 手动触发周复盘。
- 有减载建议。
- 无减载建议。
- 用户确认。
- 用户取消。
- 用户带编辑确认。
- 后端离线后由 Morning Agent 补触发。

### 3.8 闭环八：后端运行可靠性 / 错误语义

建议 change 名：

```text
clarify-assistant-backend-errors
```

目标：

把“助手离线”从万能错误改成清晰的错误状态体系，让前端能给出可恢复的反馈。

当前痛点：

- Swift 侧很多解码错误、HTTP 错误、连接错误都会变成 `AssistantOfflineError`。
- 用户无法区分后端没启动、LLM 超时、API key 缺失、URL 不支持、后端 bug。
- 调试成本和使用挫败感都被放大。

需要探索：

- 错误类型是否分为 offline、starting、timeout、badRequest、llmUnavailable、decodeMismatch、serverError。
- 后端是否统一返回 `{code, message, recoverability}`。
- 前端是否针对不同错误显示不同 CTA。
- 解码失败是否应该在开发期暴露详细信息。

前端重点：

- `AssistantAPIClient.swift`
- `LearningAssistantViewModel.swift`
- 各视图错误展示。

后端重点：

- FastAPI exception handling。
- 各 router 的错误响应。
- LLM handler 超时与错误包装。

验收重点：

- 后端未启动。
- 后端启动中。
- 404/400 输入错误。
- 500 后端错误。
- LLM timeout。
- JSON schema mismatch。
- API key 缺失。

### 3.9 闭环九：验收自动化基础设施

建议 change 名：

```text
automate-learning-assistant-acceptance
```

目标：

把目前人工验收清单升级为可重复运行的验收工具，减少后续每个闭环的人工检查成本。

当前痛点：

- `docs/acceptance-checklist.md` 已经有场景，但很多仍依赖人工执行。
- 前端 SwiftUI 视觉状态主要靠代码审查和肉眼。
- 后端 curl 场景没有统一脚本化。
- 每次修改后需要重新手工串流程。

需要探索：

- 是否新增后端 acceptance script，自动重置 DB、启动服务、执行 API 场景。
- 是否新增 Swift fixture preview 或 ViewModel state snapshot。
- 是否使用截图测试或最小 UI inspection。
- 验收报告是否自动写入 `docs/acceptance-results.md` 或单独生成。

前端重点：

- ViewModel fixture。
- SwiftUI preview/test support。

后端重点：

- `assistant_backend/tests/`
- acceptance script。
- DB reset fixture。

验收重点：

- 一条命令跑后端验收。
- 一条命令跑 Swift 单元测试。
- 可生成最新验收报告。
- 每个闭环能复用同一套 fixture。

## 4. 建议执行节奏

第一阶段先做两个最影响“前端简陋感”的闭环：

1. `redesign-learning-assistant-home`
2. `productize-learning-material-ingestion`

这两个完成后，学习助手会从“功能堆在中栏里”变成“有入口、有引导、有可信草稿”的产品体验。

第二阶段做日常使用：

3. `productize-today-learning-workbench`
4. `productize-resource-progress-roadmap`
5. `productize-conversational-planner-ui`

第三阶段做长期智能：

6. `explain-morning-briefing-and-reschedule`
7. `productize-weekly-review-experience`

第四阶段补基础设施：

8. `clarify-assistant-backend-errors`
9. `automate-learning-assistant-acceptance`

如果执行中发现错误语义阻碍前面闭环，也可以把 `clarify-assistant-backend-errors` 提前。

## 5. 每个闭环的文档模板

后续每个 OpenSpec change 建议按以下结构写。

### 5.1 proposal.md

必须说明：

- Why：这个闭环为什么现在要做。
- Affected Specs：本 change 修改哪些主 spec id；若新增 spec，需要解释为什么现有 spec 不适用。
- What Changes：前端、后端、数据、测试分别改什么。
- User Journey：用户从哪里进入，怎么完成。
- Non-Goals：明确不做哪些诱人的扩展。
- Impact：涉及文件、API、DB、测试。

### 5.2 design.md

必须说明：

- 当前实现结构。
- 新体验结构。
- 状态矩阵。
- API 契约。
- UI 信息层级。
- 错误恢复策略。
- 关键取舍与 rejected alternatives。
- Subagent 分工边界。

### 5.3 specs/*/spec.md

必须使用可验收的 requirement + scenario：

- `specs/<spec-id>/spec.md` 的 `<spec-id>` 必须与目标主 spec folder 完全一致。
- 修改已有能力时使用已有 spec-id，写 `MODIFIED Requirements`。
- 新增能力时才创建新 spec-id，写 `ADDED Requirements`。
- WHEN 用户处于某个状态或执行某个动作。
- THEN 系统展示什么、请求什么、写入什么、禁止什么。
- 每个 scenario 应能被测试、截图、curl 或人工产品判断验证。

### 5.4 tasks.md

必须按实现交接包写：

- 任务按前端、后端、测试、验收拆分。
- 每个任务标出文件边界。
- 每个任务先写测试。
- 每个任务包含验收命令。
- 明确哪些任务可并行，哪些必须顺序执行。

## 6. Definition of Done

一个闭环完成必须满足：

- OpenSpec 文档已通过用户审核。
- 所有 tasks 已完成。
- 后端测试通过。
- Swift 测试通过。
- API 验收场景通过。
- 前端关键状态已有截图或等价证据。
- spec compliance review 无阻断问题。
- code quality review 无阻断问题。
- 验收报告记录通过项、未覆盖项、残余风险。
- 若实现偏离设计，spec 已同步更新。

## 7. 下一步建议

下一步从 `redesign-learning-assistant-home` 开始。

探索时优先回答：

- 学习助手首页打开后的第一屏应该告诉用户什么。
- 空数据库用户第一步应该做什么。
- 有任务用户最需要看到什么。
- 添加资料、对话、资料进度三类入口如何降噪。
- 哪些后端数据不足以支撑一个可信首页。

这些问题回答清楚后，再创建该 change 的 OpenSpec proposal/spec/tasks，并把 subagent handoff 写进 tasks。
