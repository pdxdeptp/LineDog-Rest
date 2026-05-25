## MODIFIED Requirements

### Requirement: Tab 导航
The learning assistant middle panel SHALL use the home dashboard as the default entry after backend readiness and SHALL provide bottom navigation for Home, Add / Initiate, Material Progress, and Adjust Plan.

#### Scenario: 底部固定导航
- **WHEN** the middle panel shows Home or any learning assistant tool page
- **THEN** bottom navigation shows Home, Add / Initiate, Material Progress, and Adjust Plan
- **AND** the bottom navigation remains fixed at the bottom of the learning assistant panel

### Requirement: 添加/立项视图
The Add / Initiate tab SHALL support submitting learning or project items, route them into plan-generating or non-plan roles, and show a draft review before any active daily tasks are created.

#### Scenario: 提交目标或资料
- **WHEN** the user enters a goal text, URL, GitHub repo, existing project description, interview prep item, resume material, or note snippet and clicks continue
- **THEN** the frontend starts an Add / Initiate session that first calls intake routing to obtain recommended role, confidence, reason, and next action
- **AND** the frontend does not directly call the old URL ingest path to create active tasks

#### Scenario: 会话合同清楚
- **WHEN** Add / Initiate is processing a submission
- **THEN** the frontend tracks session id, client request id, intake item id when present, draft id when present, draft version when present, current stage, and current review state
- **AND** the frontend ignores stale progress or review events that do not match the current session/draft identity

#### Scenario: 角色确认
- **WHEN** intake route returns a recommended role
- **THEN** the frontend shows low-cost confirmation controls that allow the user to accept or switch to new plan, attach to existing plan, reference material, later resource, or explicit one-off action
- **AND** when the frontend shows "supporting material", that choice is written as existing-plan attachment plus `material_only`
- **AND** if the role does not require scheduling, the frontend offers storage or attachment confirmation rather than plan-generation controls

#### Scenario: 生成计划草案
- **WHEN** the user confirms that the item needs a new plan or existing-plan scheduled phase/work
- **THEN** the frontend collects or displays deadline, available time, target output, target depth, and assumptions
- **AND** the frontend allows the user to accept visible assumptions before generating the draft
- **AND** the frontend sends confirmed anchors through the Add / Initiate orchestration adapter rather than calling router, compiler, and scheduler helpers as unrelated one-off operations

#### Scenario: 需要补信息时只问一个关键问题
- **WHEN** the session enters `needs_input`
- **THEN** the frontend shows one focused question plus the currently known role, anchors, and assumptions
- **AND** answering the question resumes planning progress without forcing the user to restart the whole Add / Initiate session

#### Scenario: 生成失败可恢复
- **WHEN** the session enters `compile_failed`
- **THEN** the frontend preserves the submitted input, confirmed role, anchors, and accepted assumptions
- **AND** the user can retry, simplify input, store for later, or cancel without creating active tasks

#### Scenario: 展示处理进度
- **WHEN** Add / Initiate is analyzing, routing, previewing source, generating phases, generating tasks, validating tasks, scheduling, or preparing review
- **THEN** the frontend displays the current processing stage
- **AND** it does not display processing as created Today tasks

#### Scenario: 展示计划草案
- **WHEN** the backend returns a plan draft
- **THEN** the frontend defaults to a compact summary of role, assumptions, first-week daily schedule, buffer, low-energy fallback, capacity risk, and deadline risk
- **AND** full schedule, source structure, and per-task edits are available through explicit expansion controls
- **AND** the draft still does not enter Today

#### Scenario: 首屏草案摘要不刷屏
- **WHEN** the frontend shows a draft review
- **THEN** it uses the first seven calendar days from scheduled review data, or the full window when shorter, for the first-week summary
- **AND** it shows day date, planned minutes, load state, and fallback/risk cues without rendering every scheduled item by default

#### Scenario: fallback 不是新的待办
- **WHEN** a scheduled item includes low-energy fallback metadata
- **THEN** the frontend displays fallback output and risk effect as an alternate execution mode
- **AND** it does not render fallback as a separate Today task or mark normal work complete from fallback metadata alone

#### Scenario: 不可行草案显示选择而不是错误
- **WHEN** the backend returns an infeasible review draft
- **THEN** the frontend shows capacity gap, overload, expected-late work, or buffer erosion facts
- **AND** it offers localized choices backed by canonical option ids such as `reduce_scope`, `lower_depth`, `extend_deadline`, `increase_capacity`, `accept_crunch`, `accept_buffer_risk`, `accept_overload`, `accept_late_finish`, or `store_for_later`

#### Scenario: 不可行选项先返回新审阅态
- **WHEN** the user selects an infeasibility option
- **THEN** the frontend shows option-effect progress while preserving the current review package
- **AND** the result is a new review package, storage state, compiler-recompute handoff, or focused input state before activation is offered

#### Scenario: 硬 deadline 不提供接受延期
- **WHEN** an infeasible draft has deadline type `hard`
- **THEN** the frontend does not display an `accept_late_finish` option
- **AND** it only shows options that change scope, depth, deadline, capacity, overload/crunch, or storage

#### Scenario: 确认草案
- **WHEN** the user clicks confirm/initiate on a reviewed draft
- **THEN** the frontend calls the activation endpoint for the current draft id and version
- **AND** success refreshes Home, Today, project overview, and calendar facts

#### Scenario: 激活失败保留草案
- **WHEN** activation fails
- **THEN** the frontend keeps the current draft and error state
- **AND** the user can retry activation, continue editing, or cancel

#### Scenario: 旧响应不能覆盖新状态
- **WHEN** a retry, option effect, progress event, or activation response returns after the user has moved to a newer session or draft version
- **THEN** the frontend ignores the stale response
- **AND** it keeps the newer review state visible

#### Scenario: 草案过期时阻止激活
- **WHEN** the user attempts to activate a stale draft version
- **THEN** the frontend displays that the draft has changed or expired
- **AND** it does not write the old version into active plan state

#### Scenario: 非计划条目不制造提醒噪音
- **WHEN** the user stores an item as supporting material, reference material, or later resource
- **THEN** the frontend does not create Today badges, deadline risk prompts, or smart-mode proposal entries for that item
- **AND** the item is visible only from the relevant plan material or resource list

#### Scenario: 只有激活成功刷新主动学习表面
- **WHEN** the session is in route review, anchor review, progress, needs input, compile failed, infeasible review, draft review, storage, attachment, or activation failure
- **THEN** the frontend does not refresh Home, Today, Calendar, or smart-mode surfaces as if new active work exists
- **AND** when activation succeeds, the frontend refreshes Home, Today, project overview, active Calendar facts, and smart-mode proposal context
