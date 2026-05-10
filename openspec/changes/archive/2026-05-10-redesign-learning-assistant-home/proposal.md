## Why

学习助手中栏目前以“今日任务 / 资料进度 / 对话 / 添加资料”四个同级 Tab 呈现，更像调试面板，而不是用户每天打开后能立刻理解状态与下一步行动的工作台。同时当前控制面板把学习助手挤在约 280pt 宽的中栏里，空间不足会持续放大后续资料导入、任务工作台和计划调整体验的问题。

本 change 先完成“打开桌宠面板 → 看懂今日摘要 → 自主安排今日任务 → 快速进入学习资料或工具页”的体验闭环，为后续学习助手各功能点产品化打底。

## Affected Specs

- `assistant-panel-ui`: 修改学习助手默认首页、底部导航、离线状态、今日任务排序、任务详情和学习链接跳转体验。
- `desk-pet-controls`: 修改桌宠 popover 控制面板的横向布局要求，使左右栏固定宽度，中间学习助手栏随屏幕宽度自适应。
- `daily-morning-agent`: 修改今日简报任务 API 契约，使任务项携带可供前端快速打开学习资料的链接字段。

## What Changes

- 将默认入口从“今日任务 Tab”改为学习助手首页 dashboard，第一优先级展示“今日摘要”，不替用户强推下一项任务。
- 将“首页 / 添加资料 / 资料进度 / 调整计划”做成固定在学习助手中栏底部的导航栏，与上方可滚动信息流分离。
- 今日任务列表允许用户拖拽调整当前展示顺序；该顺序仅用于当前首页体验，不改变 Morning Agent 排期、任务 priority 或 scheduled_date。
- 今日任务卡片可点击展开轻量详情；详情里提供明确的“打开链接”动作，用于快速跳转到要学的资料或单元。
- 空数据库首次打开时把“添加第一份资料”作为主路径，而不是把空状态描述成终点。
- 离线状态简化为整个学习助手中栏的服务不可用页；不保留旧内容、不做局部失败或缓存可用状态。
- 桌宠 popover 横向接近占满当前屏幕可见宽度，左提醒栏和右控制栏固定宽度，中间学习助手栏自适应占据剩余空间。
- 前端验收覆盖空数据库、后端启动中、整栏离线、有今日任务、有资料但今日无任务、deadline 风险、底部导航、任务展开、学习链接、任务拖拽排序和宽屏布局。

## User Journey

### Journey 1: 打开首页看懂今天

- **Entry**: 用户点击桌宠打开控制面板。
- **Main Path**: popover 以宽屏布局打开；用户先看到学习助手首页的今日摘要、总分钟数、任务数量和资料风险。
- **Success**: 用户不用切 Tab 就知道今天整体学习状态。
- **Failure**: 后端不可用时，学习助手中栏整体显示服务不可用和重试入口。
- **Exit**: 用户关闭 popover，或通过底部导航进入添加资料、资料进度、调整计划。

### Journey 2: 第一次使用添加资料

- **Entry**: 用户打开首页，系统没有今日任务和资料。
- **Main Path**: 首页显示空数据库状态，并把“添加第一份资料”作为主行动。
- **Success**: 用户进入添加资料入口。
- **Failure**: 后端不可用时进入整栏离线状态。
- **Exit**: 用户进入添加资料，或关闭 popover。

### Journey 3: 自主安排今日任务并开始学习

- **Entry**: 用户在首页看到今日任务列表。
- **Main Path**: 用户拖拽任务调整当前展示顺序；点击任务展开轻量详情；点击“打开链接”进入学习资料。
- **Success**: 用户按自己选择的顺序开始学习，并能快速跳到资料。
- **Failure**: 任务没有可打开链接时，前端显示不可跳转状态，不伪造跳转。
- **Exit**: 用户打开外部学习链接、标记任务完成、折叠详情或关闭 popover。

### Journey 4: 使用底部工具导航

- **Entry**: 用户在学习助手中栏任意滚动位置。
- **Main Path**: 底部固定导航始终显示“首页 / 添加资料 / 资料进度 / 调整计划”。
- **Success**: 用户可以稳定切换工具，不被信息流滚动影响。
- **Failure**: 后端不可用时底部导航不显示，整栏离线状态优先。
- **Exit**: 用户回到首页、进入工具页或关闭 popover。

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `assistant-panel-ui`: 默认中栏体验从四个同级 Tab 改为“首页 dashboard + 底部固定导航”，并扩展今日任务排序、任务详情、学习链接和整栏离线要求。
- `desk-pet-controls`: 桌宠 popover 控制面板从固定窄宽布局改为宽屏自适应布局。
- `daily-morning-agent`: 今日简报任务项增加学习链接字段，以支持前端快速打开资料。

## Non-Goals

- 不产品化添加资料草稿展示、资料进度路线图、对话式计划 diff 或今日任务实际用时输入。
- 不新增 dashboard summary API，除非实现阶段证明现有 API 无法满足并先同步更新 spec。
- 不改变 Morning Agent 的排期、自动重排、priority 计算或 scheduled_date 语义。
- 不引入数据库迁移来持久化任务展示顺序；本轮排序只影响首页展示体验。
- 不做重型任务详情页；任务详情只提供轻量上下文和学习链接入口。
- 不做单元级深链接抓取或解析增强；本轮只要求 task 返回可打开的资源级链接，若已有单元链接可优先使用。
- 不把离线状态设计成缓存可用、局部可用或部分失败状态。

## Impact

- SwiftUI frontend: `MalDaze/MenuBarContentView.swift`, `MalDaze/LearningAssistant/AssistantPanelView.swift`, `LearningAssistantViewModel.swift`, `AssistantAPIClient.swift`, `AssistantAPIClientProtocol.swift`, existing child views as needed for navigation handoff.
- Window/popup layout: `WindowManager` popover sizing via `MenuBarContentView.controlPanelPreferredContentSize`; implementation should keep existing `NSPopover` behavior unless design is explicitly revised.
- Backend API: `GET /api/today-briefing` task objects need a learning URL field, sourced from task unit/resource context where available.
- Swift tests: dashboard state, task ordering, task expansion, URL decoding/open action availability, bottom navigation, and wide layout fixture.
- Python tests: today briefing task payload includes link fields and preserves existing fields.
- Acceptance docs/scripts: add or update scenarios for wide popover layout, empty database, backend starting, whole-column offline, loaded tasks, task detail/link, task reordering, resources without today tasks, and deadline-risk resource states.
