## ADDED Requirements

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

### Requirement: Buffer And Low-Energy Fallback Scheduling
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

### Requirement: Deadline-Driven Plan Draft
The system SHALL generate a draft plan from confirmed planning anchors by working backward from the deadline.

#### Scenario: Deadline semantics are visible
- **WHEN** a draft uses a deadline
- **THEN** the system labels the deadline as hard, soft, or assumed
- **AND** the label is visible before activation

#### Scenario: Draft includes phases and daily work
- **WHEN** the system generates a plan draft
- **THEN** the draft includes ordered phases, daily scheduled work, target minutes, and milestone outcomes
- **AND** daily tasks are derived from the target output rather than blindly mirroring source structure

#### Scenario: Draft accounts for existing active load
- **WHEN** existing active plans already occupy time in the draft window
- **THEN** the draft shows combined daily load and conflicts against capacity
- **AND** it does not silently move existing plan tasks to make the new draft look feasible

#### Scenario: Draft includes capacity risk
- **WHEN** estimated work does not fit the available time before the deadline
- **THEN** the draft shows the required average daily minutes and capacity gap
- **AND** it offers scope reduction, deadline extension, capacity increase, or later storage as user choices

### Requirement: Compiler Dry-Run Acceptance Examples
The system SHALL be verifiable against real-context schedule examples before implementation is considered ready.

#### Scenario: Feasible dry run includes capacity math
- **WHEN** a real-context dry run fits within the confirmed deadline, capacity, and buffer policy
- **THEN** the scheduler can show essential work minutes, available execution capacity, reserved buffer, scheduled daily work, and zero capacity gap
- **AND** the draft enters `draft_review` rather than infeasible review

#### Scenario: Infeasible dry run includes option math
- **WHEN** a real-context dry run does not fit within the confirmed deadline, capacity, and buffer policy
- **THEN** the scheduler can show essential work minutes, available execution capacity, capacity gap, buffer erosion, and expected review state
- **AND** the resulting options obey target-depth, scope-reduction, and hard-deadline rules
