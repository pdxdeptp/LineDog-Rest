## ADDED Requirements

### Requirement: First-Version Input Coverage
The system SHALL support a bounded first-version set of manually submitted learning and project items.

#### Scenario: Supported first-version item types
- **WHEN** the user submits text goals, standard URLs, GitHub repo URLs, pasted note snippets, existing project descriptions, interview prep items, or resume/project material notes
- **THEN** the system accepts the input into the intake flow
- **AND** it routes the item before creating scheduled work

#### Scenario: Real-context examples are accepted
- **WHEN** the user submits examples such as AgentGuide, easyagent, LeetCode practice, agent/backend interview prep, resume rewrite, or MalDaze project work
- **THEN** the system can route each item into planning, attachment, support, reference, or later-resource roles

#### Scenario: Unsupported input falls back safely
- **WHEN** the system cannot parse or classify an input type with confidence
- **THEN** it allows manual title and description entry
- **AND** it marks any resulting plan as low-calibration or stores the item without active tasks

### Requirement: Intake Item Role Routing
The system SHALL route every submitted learning or project item into a proposed role before creating scheduled work.

#### Scenario: Item is proposed as a new plan
- **WHEN** the user submits an item that expresses a goal needing deadline-driven execution
- **THEN** the system proposes the role `new_plan`
- **AND** the system does not create active daily tasks before the user confirms a plan draft

#### Scenario: Item is proposed as existing-plan work
- **WHEN** the user submits an item that appears to be a phase, task, or material for an existing active or draft plan
- **THEN** the system proposes attaching it to that plan
- **AND** the system explains whether it will become a phase/task or supporting material

#### Scenario: Item is proposed as non-executable material
- **WHEN** the user submits a reference, inspiration, or later resource
- **THEN** the system proposes `reference_material` or `later_resource`
- **AND** it stores the item without creating scheduled tasks

#### Scenario: Ambiguous role is clarified with one question
- **WHEN** the system cannot confidently choose between planning, attaching, or storing
- **THEN** it asks one concise routing question with a recommended default
- **AND** it does not start a long questionnaire

### Requirement: User-Owned Value And Depth Decisions
The system SHALL keep value judgment and target-depth selection under user control for first-version intake.

#### Scenario: System does not judge whether goal is worth doing
- **WHEN** the user submits a goal or resource
- **THEN** the system may show estimated cost, deadline risk, and fit with active plan load
- **AND** it does not independently reject or prioritize the item based on whether it is worth learning

#### Scenario: User chooses target depth
- **WHEN** a plan-generating item needs a target depth
- **THEN** the system offers selectable completion-depth options
- **AND** the selected or assumed depth is shown before activation

#### Scenario: Target depth changes completion obligations
- **WHEN** the user selects skim/orientation, can-use, project-level, interview-ready, or source-understanding depth
- **THEN** the draft changes required completion evidence and task families to match that depth
- **AND** the draft does not treat depth as a display-only label

#### Scenario: Target depth modifier is visible
- **WHEN** the draft combines a primary depth with an additional modifier such as interview readiness or source understanding
- **THEN** the review shows the extra tasks, evidence, and risk created by that modifier
- **AND** the user can accept, remove, or lower the modifier before activation

### Requirement: Calibration And Provenance
The system SHALL expose calibration and provenance for generated routing and plan drafts.

#### Scenario: Draft shows fact sources
- **WHEN** the system shows a route recommendation or plan draft
- **THEN** it distinguishes user-provided facts, parsed source facts, AI assumptions, and unknowns
- **AND** the user can see which assumptions will be used if they accept the draft

#### Scenario: Draft is low calibration
- **WHEN** key source data is missing, parsing failed, or multiple anchors were assumed
- **THEN** the draft is marked low-calibration
- **AND** activation still requires explicit user confirmation

#### Scenario: System does not fabricate unavailable facts
- **WHEN** repo structure, source content, deadline, capacity, target output, or target depth is unavailable
- **THEN** the system leaves that fact unknown or asks for it
- **AND** it does not present fabricated details as facts

### Requirement: Minimal Planning Anchors
The system SHALL collect or assume the minimum anchors needed for a deadline-driven draft plan.

#### Scenario: Required anchors are present
- **WHEN** the item has a deadline, available time, target output, and target depth
- **THEN** the system can generate a plan draft without additional questions

#### Scenario: One or two anchors are missing
- **WHEN** the item is missing target output, target depth, deadline, or available time
- **THEN** the system asks the smallest number of questions needed or uses visible recommended assumptions
- **AND** every assumption is displayed in the draft review

#### Scenario: Deadline is missing for a planning item
- **WHEN** the item is intended to become a deadline-driven active plan but no deadline or timebox exists
- **THEN** the system asks for a deadline or offers to store the item for later
- **AND** it does not create a fake active plan

### Requirement: Intake And Draft Lifecycle State Machine
The system SHALL model Add / Initiate as an explicit lifecycle from idle through routing, review, compilation, draft review, activation, cancellation, or storage.

#### Scenario: Item moves through routing and role review
- **WHEN** the user submits an item
- **THEN** the item moves from `idle` to `intake_submitted`, `routing`, and `role_review`
- **AND** no active tasks are created during these states

#### Scenario: Non-plan item exits planning safely
- **WHEN** the user confirms a reference, later, or material-only role
- **THEN** the item moves to `stored_non_plan` or `attach_review`
- **AND** it remains excluded from Today and active scheduling

#### Scenario: Existing-plan attachment exits by attachment mode
- **WHEN** the user confirms `attach_to_existing_plan`
- **THEN** `material_only` exits to stored non-plan attachment
- **AND** `draft_phase` or `scheduled_work` continues to anchor review before compilation
- **AND** no active tasks are created until draft activation

#### Scenario: Planning item moves through compile states
- **WHEN** the user confirms a plan-generating role and anchors
- **THEN** the item can move through `anchor_review`, `compiling`, `needs_input`, `compile_failed`, `infeasible_review`, and `draft_review`
- **AND** each state has a user-visible recovery path

#### Scenario: Activation uses latest draft version
- **WHEN** the user activates a draft
- **THEN** the item moves through `activating` to `active_plan`
- **AND** activation fails safely if the selected draft version is stale

#### Scenario: Cancellation before activation creates no tasks
- **WHEN** the user cancels before `active_plan`
- **THEN** the system creates no active tasks
- **AND** the user can discard the intake item or store it as later/reference

### Requirement: Plan Compiler Data Contracts
The system SHALL use versioned logical data contracts for plan compiler inputs, outputs, validation errors, and schedule risk reports.

#### Scenario: Planning envelope includes required facts
- **WHEN** the compiler starts
- **THEN** it receives a versioned planning envelope containing intake id, confirmed role, archetype, deadline and type, capacity, rest days, unavailable dates, target output, target depth, source summaries, source roles, existing active load, and provenance
- **AND** optional fields can include user constraints, preferred load shape, existing plan id, attachment mode, and material role

#### Scenario: Plan draft package is versioned
- **WHEN** the compiler returns a draft package
- **THEN** the package includes schema version, draft id, draft version, intake id, status, summary, assumptions, review summary, and activation eligibility
- **AND** status-specific plan, schedule, risk, missing-input, or validation fields follow the package status

#### Scenario: Reviewable draft package includes plan details
- **WHEN** the compiler returns `draft_review` or `infeasible_review`
- **THEN** the package includes phases, task candidates, scheduled tasks when available, and risk report
- **AND** `infeasible_review` includes canonical infeasibility options and is not activatable until the user chooses an allowed option

#### Scenario: Blocked draft package includes recovery details
- **WHEN** the compiler returns `needs_input` or `compile_failed`
- **THEN** the package includes missing facts or validation errors plus recovery actions
- **AND** it does not require complete phases, tasks, schedule, or risk report

#### Scenario: Validation errors are structured
- **WHEN** validation fails
- **THEN** each validation error includes code, severity, target, user-facing message, and repair hint when available
- **AND** blocking validation errors cannot enter draft review

#### Scenario: Low-calibration draft is structurally valid
- **WHEN** validation leaves warning-level uncertainty after bounded repair
- **THEN** the draft may enter review only if no blocking validation errors remain
- **AND** the warning-level assumptions are visible before activation

#### Scenario: Blocking validation failure is not activatable
- **WHEN** phase or task output still lacks executable output, completion criteria, valid dependency structure, or normalizable estimates after bounded repair
- **THEN** the compiler returns `compile_failed` or `needs_input`
- **AND** the system does not present the draft as activatable

#### Scenario: Risk report has scheduling facts
- **WHEN** scheduling completes
- **THEN** the risk report includes fit status, capacity gap, overloaded dates, expected-late tasks, reserved buffer days, buffer erosion, estimate confidence summary, existing-load conflicts, and infeasibility options

### Requirement: Draft Versioning And Recompile Rules
The system SHALL version plan drafts and choose the smallest required recomputation after user edits.

#### Scenario: Schedule-only edit reschedules draft
- **WHEN** the user edits deadline, capacity, unavailable dates, rest days, task estimate, load shape, or crunch acceptance
- **THEN** the system creates a new draft version by rerunning deterministic scheduling
- **AND** it does not rerun LLM task generation unless task structure changed

#### Scenario: Scope edit regenerates tasks
- **WHEN** the user edits target output, target depth, archetype, phase scope, or asks to rewrite/split/merge tasks
- **THEN** the system creates a new draft version by regenerating task candidates and rerunning scheduling

#### Scenario: Non-plan edit does not compile
- **WHEN** the user edits display text, stores a non-plan item, or attaches material without scheduled work
- **THEN** no plan compiler run is required

#### Scenario: Previous draft version remains recoverable
- **WHEN** a recompile or reschedule creates a new draft version
- **THEN** the previous version remains recoverable until activation or discard

### Requirement: Existing Plan Attachment Semantics
The system SHALL distinguish material-only, draft-phase, and scheduled-work attachment modes for existing plans.

#### Scenario: Existing plan role uses attachment mode
- **WHEN** the router decides an item belongs to an existing active or draft plan
- **THEN** the machine role is `attach_to_existing_plan`
- **AND** the specific behavior is stored as `material_only`, `draft_phase`, or `scheduled_work`
- **AND** a user-facing supporting-material choice maps to `material_only`

#### Scenario: Material-only attachment does not alter schedule
- **WHEN** the user attaches an item to an existing plan as material only
- **THEN** the existing plan schedule remains unchanged
- **AND** no new active task is created

#### Scenario: Draft phase attachment is reviewable
- **WHEN** the user attaches an item as a draft phase under an existing plan
- **THEN** the system creates a draft scoped to that existing plan
- **AND** it is not activated until draft review confirmation

#### Scenario: Activating existing-plan work does not move existing tasks
- **WHEN** the user activates scheduled work under an existing plan
- **THEN** the system adds confirmed tasks through deterministic scheduling
- **AND** it does not silently move existing active tasks
- **AND** overload or expected-late effects are shown before activation

### Requirement: Plan Compiler Contract
The system SHALL generate plan drafts through a staged compiler rather than a single prompt that directly returns a calendar.

#### Scenario: Compiler receives normalized envelope
- **WHEN** the user confirms that an item should become a new plan or an attachment to an existing plan with scheduled work
- **THEN** the compiler receives a structured envelope containing role, archetype, deadline, deadline type, capacity, target output, target depth, source summaries, existing active load, rest days, and provenance
- **AND** missing or assumed fields remain explicitly marked

#### Scenario: Compiler returns structured draft package
- **WHEN** compilation succeeds
- **THEN** the system returns a structured draft package containing assumptions, phases, milestones, executable task candidates, estimates, fallback modes, schedule facts, risk report, infeasibility options if any, and review summary

#### Scenario: LLM does not own date placement
- **WHEN** LLM-generated decomposition includes suggested dates
- **THEN** the system treats those dates as non-authoritative
- **AND** final scheduled dates are assigned only by deterministic scheduling logic

### Requirement: Structured LLM Output Validation
The system SHALL validate all LLM phase and task outputs against narrow schemas before using them in a draft.

#### Scenario: Phase output is schema-validated
- **WHEN** the LLM generates phases
- **THEN** each phase must include id, title, purpose, essential status, effort range, completion evidence, milestones, and assumptions
- **AND** phases missing observable completion evidence are rejected or repaired

#### Scenario: Task output is schema-validated
- **WHEN** the LLM generates task candidates
- **THEN** each task must include id, phase id, order, action title, concrete output, completion criteria, estimate, confidence, dependencies, normal mode, fallback mode when useful, and assumptions
- **AND** date fields from LLM output are ignored or rejected

#### Scenario: Invalid LLM output has bounded repair
- **WHEN** LLM output fails schema or quality validation
- **THEN** the system may run at most a bounded repair loop
- **AND** unresolved blocking failures return `compile_failed` or `needs_input`
- **AND** unresolved warning-level uncertainty may mark a structurally valid draft low-calibration rather than producing a confident plan

### Requirement: Phase And Milestone Decomposition
The system SHALL decompose plan-generating items into observable phases and milestones before creating daily tasks.

#### Scenario: Phases have observable outcomes
- **WHEN** the compiler creates phases
- **THEN** each phase includes purpose, rough effort, essential-or-optional status, and completion evidence
- **AND** completion evidence is observable, such as a running demo, written notes, solved problem set, rewritten resume bullets, or mock explanation

#### Scenario: Archetype shapes phases
- **WHEN** the selected archetype is rebuild or clone, recurring practice, topic review, project packaging, finite learning project, or existing-project phase
- **THEN** generated phases follow the decomposition rules for that archetype
- **AND** the compiler does not force every archetype into a course-chapter structure

### Requirement: Executable Task Candidate Contract
The system SHALL create executable task candidates with concrete outputs before scheduling.

#### Scenario: Task candidate fields
- **WHEN** the compiler creates a task candidate
- **THEN** the task includes action title, concrete output, completion criteria, estimated minutes, dependency or predecessor, phase link, normal mode, fallback mode when useful, split points when a task may span sessions, confidence, and assumptions
- **AND** source or material references are attached when applicable

#### Scenario: Task candidates are not scheduled by the LLM
- **WHEN** task candidates are created
- **THEN** they are ordered by dependency and phase
- **AND** they do not become dated daily tasks until deterministic scheduling runs

#### Scenario: Real-context task examples are executable
- **WHEN** the compiler handles real-context items such as AgentGuide, easyagent, LeetCode, agent/backend interview prep, or resume packaging
- **THEN** generated tasks have concrete outputs such as runnable demo evidence, setup notes, solved problem sets, mistake tags, interview answers, or rewritten resume bullets
- **AND** vague outputs such as "learn the repo" or "understand the topic" are not accepted

### Requirement: Task Quality Gates
The system SHALL validate task candidates before scheduling them into a draft.

#### Scenario: Vague task is rejected or repaired
- **WHEN** a task candidate lacks an action verb, concrete output, completion criteria, or executable stopping condition
- **THEN** the compiler rejects or repairs the candidate before scheduling
- **AND** tasks such as "learn LangGraph", "understand agent memory", "work on resume", or "study repo" are not accepted as final executable tasks

#### Scenario: Oversized task is split
- **WHEN** a task candidate is estimated over the configured large-task threshold
- **THEN** the compiler splits it at meaningful checkpoints or marks it as a multi-session milestone
- **AND** it does not schedule the oversized task as one ordinary daily task

#### Scenario: Tiny task is merged unless it is a checkpoint
- **WHEN** a task candidate is too small to stand alone
- **THEN** the compiler merges it into a neighboring task unless it is a checkpoint, review action, or low-energy fallback

#### Scenario: Repair loop is bounded
- **WHEN** task quality validation fails
- **THEN** the system may request a bounded LLM repair
- **AND** if repair still leaves blocking errors, the compiler returns `compile_failed` or `needs_input`
- **AND** if repair leaves only warning-level uncertainty, the draft can be marked low-calibration and the user is asked to confirm, edit, or cancel

### Requirement: Estimate Normalization
The system SHALL normalize task estimates before scheduling.

#### Scenario: Source facts inform estimates
- **WHEN** source facts such as video duration, module count, problem count, or known review cadence are available
- **THEN** the system uses those facts to inform task estimates
- **AND** it records estimate confidence

#### Scenario: Estimate sources have priority
- **WHEN** the system normalizes a task estimate
- **THEN** it prioritizes user-provided estimates, concrete source facts, user history when available, archetype defaults, and LLM suggestions in that order
- **AND** LLM estimates do not override stronger deterministic facts

#### Scenario: Archetype defaults fill missing estimates
- **WHEN** a task estimate is missing and no concrete duration/count fact is available
- **THEN** the system applies the documented archetype or work-type default estimate
- **AND** the estimate confidence is recorded as medium or low based on the available source signals

#### Scenario: LLM estimates are clamped or flagged
- **WHEN** LLM-generated estimates are missing, extreme, or inconsistent with archetype rules
- **THEN** the system applies deterministic defaults, clamps, or risk flags
- **AND** the draft review shows that the estimate is rough when confidence is low

#### Scenario: Low estimate confidence marks draft calibration
- **WHEN** low-confidence estimates cover a significant share of essential work
- **THEN** the draft is marked low-calibration with visible rough-estimate assumptions
- **AND** activation still requires explicit user confirmation or estimate edits

### Requirement: Deterministic Draft Scheduling
The system SHALL assign dates to validated task candidates with deterministic scheduling logic.

#### Scenario: Scheduler consumes validated tasks
- **WHEN** task candidates pass quality and estimate checks
- **THEN** the scheduler assigns dates using dependency order, daily capacity, existing active load, rest days, unavailable dates, buffer policy, deadline, and deadline type
- **AND** it does not invent new learning content while scheduling

#### Scenario: Scheduler preserves dependency order
- **WHEN** tasks have dependencies or predecessors
- **THEN** scheduled dates preserve those ordering constraints unless the draft is explicitly marked infeasible

#### Scenario: Scheduler reports infeasibility as valid output
- **WHEN** the plan cannot fit within the deadline and capacity constraints
- **THEN** the scheduler returns a draft with overload, expected-late, buffer-erosion, or capacity-gap facts
- **AND** it does not silently change target depth, deadline, or user capacity

#### Scenario: Scheduler computes usable capacity
- **WHEN** the scheduler evaluates a date
- **THEN** it computes usable capacity from user capacity, rest-day or unavailable-day state, and existing active plan load
- **AND** it prevents the new draft from consuming every free minute unless the user chooses crunch or overload

#### Scenario: Scheduler uses capacity default consistently
- **WHEN** no explicit daily capacity is available
- **THEN** the scheduler uses the learning preference default of 60 minutes
- **AND** it does not use 300 minutes as a fallback

#### Scenario: Scheduler places essential work before optional work
- **WHEN** the scheduler places tasks
- **THEN** essential tasks are placed before optional or stretch work
- **AND** optional work remains unscheduled or attached only to low-load days when capacity is tight

#### Scenario: Scheduler supports load shapes
- **WHEN** the user or default settings choose balanced, front-loaded, or light-start scheduling
- **THEN** the scheduler uses that load shape while preserving dependencies, capacity facts, and deadline risk reporting

#### Scenario: Task is split across low-capacity days
- **WHEN** a validated task estimate exceeds the normal planning budget for available days
- **THEN** the scheduler splits it into dated continuation sessions only at approved split points or explicit multi-session boundaries
- **AND** each session keeps the parent task, sequence order, estimated minutes, and visible sub-output or continuation note
- **AND** the scheduler does not place an over-budget single-day task unless the user explicitly accepts crunch or overload

#### Scenario: Unsplittable task cannot fit
- **WHEN** a task cannot be meaningfully split and cannot fit any available day
- **THEN** the scheduler returns expected-late, overloaded-date, or capacity-gap facts
- **AND** the draft enters infeasible review instead of silently creating an unrealistic daily plan

### Requirement: Infeasibility Options
The system SHALL convert infeasible schedule facts into explicit user choices.

#### Scenario: Capacity gap produces choices
- **WHEN** the draft has a capacity gap, expected-late state, overload, or buffer erosion
- **THEN** the system presents canonical choices such as `reduce_scope`, `lower_depth`, `extend_deadline`, `increase_capacity`, `accept_crunch`, `accept_buffer_risk`, `accept_overload`, `accept_late_finish`, or `store_for_later`
- **AND** the user chooses the path before activation

#### Scenario: LLM may explain but not choose
- **WHEN** infeasibility options are shown
- **THEN** LLM-generated text may explain tradeoffs
- **AND** the selected option is not applied unless the user explicitly chooses it

#### Scenario: Infeasibility maps to specific facts
- **WHEN** the schedule has capacity gap, buffer erosion, overloaded dates, expected-late tasks, or low calibration
- **THEN** the system presents choices mapped to those facts
- **AND** it does not show generic advice without the concrete scheduling reason

#### Scenario: Infeasibility choice has deterministic effect
- **WHEN** the user chooses reduce scope, lower depth, extend deadline, increase capacity, accept crunch, accept buffer risk, accept overload, answer one question, edit estimates, accept rough draft, accept late finish, or store for later
- **THEN** the system applies the documented effect for that choice to a new draft version or storage state
- **AND** it does not silently apply any unchosen fix

#### Scenario: Reduce scope preserves target output and depth
- **WHEN** the user chooses `reduce_scope`
- **THEN** the system removes or unschedules stretch work, optional work, optional source sections, secondary modifiers, or excess practice volume before touching essential work
- **AND** it does not remove the minimal completion evidence required by the confirmed target output and target depth

#### Scenario: Lower depth changes obligations visibly
- **WHEN** the user chooses `lower_depth`
- **THEN** the system changes target-depth obligations, regenerates affected phases or tasks, and reschedules into a new draft version
- **AND** the review shows removed or changed evidence, changed minutes, and the new fit or risk state before activation

#### Scenario: Scope reduction cannot satisfy constraints
- **WHEN** no optional or stretch work remains and the draft still does not fit
- **THEN** `reduce_scope` is not presented as a standalone fix
- **AND** the system offers alternatives such as lowering depth, changing output, extending deadline, increasing capacity, accepting crunch, or storing for later

#### Scenario: Infeasibility option ids are canonical
- **WHEN** the compiler, scheduler, or UI exchanges infeasibility options
- **THEN** it uses the documented canonical option ids
- **AND** user-facing labels may be localized without changing the stored option id

#### Scenario: Late finish is unavailable for hard deadlines
- **WHEN** the deadline type is hard and required work is expected late
- **THEN** the system does not offer `accept_late_finish`
- **AND** available options require changing scope, depth, deadline, capacity, overload/crunch acceptance, or storing for later

### Requirement: Compiler Dry-Run Acceptance Examples
The system SHALL be verifiable against real-context compiler examples before implementation is considered ready.

#### Scenario: AgentGuide dry run
- **WHEN** the input is AgentGuide as a main learning object with project-level or interview-ready target depth
- **THEN** the compiler can produce phases for orientation, guided reproduction, small agent demo, interview notes, and review
- **AND** tasks include concrete outputs rather than generic "learn AgentGuide" work

#### Scenario: easyagent dry run
- **WHEN** the input is easyagent as a rebuild or clone target
- **THEN** the compiler can produce tasks for running or inspecting baseline, tracing architecture, rebuilding a minimal loop, modifying one point, and preparing demo/explanation evidence

#### Scenario: LeetCode dry run
- **WHEN** the input is LeetCode Hot 100 or 灵茶山基础精炼
- **THEN** the compiler uses recurring practice cadence, mistake tagging, redo loops, and checkpoint sets
- **AND** it does not require parsed source chapters

#### Scenario: Interview prep dry run
- **WHEN** the input is agent or backend interview prep
- **THEN** the compiler uses topic review, active recall, project-linked examples, mock explanation, and spaced review tasks

#### Scenario: Resume packaging dry run
- **WHEN** the input is resume or project packaging work
- **THEN** the compiler creates tasks for evidence inventory, bullet rewrite, project narrative, rehearsal, and revision
- **AND** completion evidence is written bullets, story drafts, or mock explanation notes

#### Scenario: Feasible dry run includes capacity math
- **WHEN** a real-context dry run fits within the confirmed deadline, capacity, and buffer policy
- **THEN** the compiler can show essential work minutes, available execution capacity, reserved buffer, scheduled daily work, and zero capacity gap
- **AND** the draft enters `draft_review` rather than infeasible review

#### Scenario: Infeasible dry run includes option math
- **WHEN** a real-context dry run does not fit within the confirmed deadline, capacity, and buffer policy
- **THEN** the compiler can show essential work minutes, available execution capacity, capacity gap, buffer erosion, and expected review state
- **AND** the resulting options obey target-depth, scope-reduction, and hard-deadline rules

### Requirement: Deadline-Driven Plan Draft
The system SHALL generate a draft plan from confirmed planning anchors by working backward from the deadline.

#### Scenario: Deadline semantics are visible
- **WHEN** a draft uses a deadline
- **THEN** the system labels the deadline as hard, soft, or assumed
- **AND** the label is visible before activation

#### Scenario: Draft selects a plan archetype
- **WHEN** the system generates a plan draft
- **THEN** it assigns a plan archetype such as finite learning project, recurring practice, topic review cycle, rebuild or clone, project packaging, or existing-project phase
- **AND** the archetype affects phase and daily-task generation

#### Scenario: Archetype selection uses explicit signals
- **WHEN** the compiler selects an archetype
- **THEN** it uses confirmed intake role, attachment mode, source roles, target output, target depth, source type, existing-plan context, and user constraints as selection inputs
- **AND** it records the selected primary archetype, any secondary modifiers, included or excluded materials, confidence, and visible assumptions

#### Scenario: Ambiguous archetype is handled narrowly
- **WHEN** multiple plan archetypes would produce materially different daily work and no signal clearly wins
- **THEN** the compiler returns `needs_input` with one archetype-focused question or creates a low-calibration draft with a visible assumption when the difference is low impact
- **AND** it does not generate a mixed plan that combines incompatible daily-work shapes without user confirmation

#### Scenario: Draft includes phases and daily work
- **WHEN** the system generates a plan draft
- **THEN** the draft includes ordered phases, daily scheduled work, target minutes, and milestone outcomes
- **AND** daily tasks are derived from the target output rather than blindly mirroring source structure

#### Scenario: Recurring practice uses cadence and review loops
- **WHEN** the selected archetype is recurring practice or topic review cycle
- **THEN** the draft can schedule practice cadence, review days, and redo or recall loops
- **AND** it does not require a parsed source structure to create useful daily work

#### Scenario: Draft uses capacity and rest-day facts
- **WHEN** the system schedules the draft
- **THEN** it uses available daily minutes, rest days, unavailable dates, and the deadline window
- **AND** it marks overload or expected-late states instead of silently hiding them

#### Scenario: Draft accounts for existing active load
- **WHEN** existing active plans already occupy time in the draft window
- **THEN** the draft shows combined daily load and conflicts against capacity
- **AND** it does not silently move existing plan tasks to make the new draft look feasible

#### Scenario: Draft includes capacity risk
- **WHEN** estimated work does not fit the available time before the deadline
- **THEN** the draft shows the required average daily minutes and capacity gap
- **AND** it offers scope reduction, deadline extension, capacity increase, or later storage as user choices

### Requirement: Buffer And Low-Energy Fallback
The system SHALL include buffer and low-energy fallback planning in generated drafts.

#### Scenario: Draft reserves buffer where possible
- **WHEN** the deadline window has enough non-rest days
- **THEN** the draft reserves explicit buffer time before the deadline
- **AND** the buffer is visible in review

#### Scenario: Buffer erosion is visible
- **WHEN** a draft can fit only by consuming planned buffer
- **THEN** the draft marks buffer erosion as a risk
- **AND** the user can choose whether to accept that risk, reduce scope, extend the deadline, or increase capacity

#### Scenario: Draft exposes fallback mode
- **WHEN** a scheduled day has meaningful work
- **THEN** the draft may include a low-energy fallback for that day
- **AND** the fallback is attached to the day as a reduced execution mode rather than a separate noisy todo
- **AND** the draft explains whether using the fallback preserves momentum, creates follow-up work, or changes risk

#### Scenario: Fallback completion does not fake full completion
- **WHEN** the user later completes only the low-energy fallback for a planned task
- **THEN** the system records partial progress or adjustment need
- **AND** it does not mark the full task complete unless the full task was completed

#### Scenario: Fallback completion keeps follow-up visible
- **WHEN** only fallback mode is completed for a scheduled task
- **THEN** the system records fallback completion time and actual minutes when available
- **AND** the full task remains incomplete with `needs_followup`
- **AND** later rollover or adjustment logic can still account for the remaining work

### Requirement: Add Initiate Async Feedback And Recovery
The system SHALL expose stage-level progress and recovery paths during routing, preview, compilation, scheduling, and activation.

#### Scenario: Progress stages are visible
- **WHEN** Add / Initiate processing is running
- **THEN** the UI can show stages such as analyzing input, routing item, previewing source, generating phases, generating tasks, validating tasks, scheduling, and preparing review

#### Scenario: Preview or generation failure is recoverable
- **WHEN** material preview, LLM generation, validation, or scheduling cannot complete normally
- **THEN** the user can retry, simplify input, answer one question, continue manually when safe, store for later, or cancel

#### Scenario: Activation failure preserves draft
- **WHEN** plan activation fails
- **THEN** the current draft version remains intact
- **AND** the user can retry activation without recreating the plan from scratch

### Requirement: Compiler Trace And Observability
The system SHALL expose implementation-facing compiler trace facts for tests and debugging without exposing sensitive raw content or hidden reasoning.

#### Scenario: Compiler records validation and scheduling trace
- **WHEN** the compiler creates, repairs, schedules, or rejects a draft
- **THEN** the trace records envelope fact provenance, selected archetype, attachment mode when applicable, schema validation results, repair attempt count, task quality gate outcomes, estimate normalization decisions, scheduler placement facts, continuation-session splits, risk facts, and canonical infeasibility option ids
- **AND** trace records are sufficient for contract tests to explain why a draft was low-calibration, infeasible, or rejected

#### Scenario: Trace avoids sensitive raw content
- **WHEN** the input contains resume text, interview prep, private project notes, private repo descriptions, or Obsidian snippets
- **THEN** trace records redact or summarize sensitive raw text
- **AND** they do not expose raw prompts or hidden chain-of-thought in user-facing UI

### Requirement: Sensitive Input Boundary
The system SHALL treat resume text, interview prep, project notes, private repo descriptions, and Obsidian snippets as sensitive planning input.

#### Scenario: No broad vault submission
- **WHEN** the user submits a note snippet or project context
- **THEN** the system uses only the submitted snippet and explicitly attached material
- **AND** it does not silently send broader Obsidian vault contents to an LLM

#### Scenario: Existing provider settings are reused
- **WHEN** implementation uses an external LLM provider
- **THEN** it reuses existing provider settings and does not introduce hidden provider behavior in this capability

### Requirement: GitHub Repository Role Handling
The system SHALL treat GitHub repositories as first-class intake inputs with explicit roles.

#### Scenario: Repository can become a main learning object
- **WHEN** the user submits a GitHub repo as the main thing to learn
- **THEN** the system uses shallow repo metadata to help generate a plan draft
- **AND** it records the repo role as `main_learning_object`

#### Scenario: Repository can be supporting or reference material
- **WHEN** the user submits a GitHub repo as reference, project material, clone/rebuild target, or later reading
- **THEN** the system records the canonical repo role as `reference_source`, `project_material`, `clone_rebuild_target`, or `later_reading`
- **AND** it does not automatically convert the repo into active daily tasks

#### Scenario: Repository fetch fails
- **WHEN** shallow repo metadata cannot be fetched
- **THEN** the system lets the user continue with manually supplied title or description
- **AND** any generated draft is marked low-calibration

### Requirement: Draft Review And Activation
The system SHALL keep generated plans in draft review until the user explicitly activates them.

#### Scenario: Draft is reviewable
- **WHEN** a plan draft is generated
- **THEN** the user can review role, assumptions, deadline, target output, target depth, phases, daily schedule, buffer, and risk states
- **AND** the draft does not affect Today or active Calendar views

#### Scenario: Draft review is summary-first
- **WHEN** the user first sees a plan draft
- **THEN** the system shows a compact summary of role, deadline fit, assumptions, first-week schedule, buffer, and risk
- **AND** full schedule details, source details, and per-task edits are available behind explicit expansion controls

#### Scenario: User confirms draft
- **WHEN** the user activates a reviewed draft
- **THEN** the system creates an active plan with scheduled tasks
- **AND** those tasks become eligible for Today, Calendar, adjustment, and smart-mode proposal flows

#### Scenario: User cancels draft
- **WHEN** the user cancels a draft
- **THEN** the system does not create active tasks
- **AND** the user may discard the intake item or keep it as later material

### Requirement: Add-Time Noise Boundaries
The system SHALL prevent submitted items from creating task noise before confirmation.

#### Scenario: One item creates one pending object
- **WHEN** the user submits one item
- **THEN** the system creates at most one visible pending role confirmation, draft, or stored-item confirmation for that submission
- **AND** it does not explode the input into multiple independent todos or alerts

#### Scenario: Supporting material does not create today action
- **WHEN** the user adds supporting material to an existing plan
- **THEN** the material is attached to the plan
- **AND** no new Today task is created unless the user explicitly adds or confirms scheduled work

#### Scenario: Draft does not create today action
- **WHEN** a generated plan is still in draft review
- **THEN** no task from that draft appears in Today
- **AND** no smart suggestion is triggered from that draft

#### Scenario: Confirmed plans drive Today
- **WHEN** the user opens Today
- **THEN** Today contains tasks from confirmed active plans only
- **AND** it excludes references, later resources, and unconfirmed drafts

#### Scenario: Immediate one-off requires explicit action
- **WHEN** the router proposes `immediate_one_off`
- **THEN** the system requires the user to explicitly create or schedule that one-off action
- **AND** it does not automatically add it to Today
