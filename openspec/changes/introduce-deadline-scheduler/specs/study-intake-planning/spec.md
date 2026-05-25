## ADDED Requirements

### Requirement: Deterministic Draft Scheduling
The system SHALL assign dates to validated task candidates with deterministic scheduling logic.

#### Scenario: Scheduler accepts only compiler-ready packages
- **WHEN** the upstream compiler package status is `needs_input` or `compile_failed`
- **THEN** the scheduler does not attempt date placement
- **AND** the package remains in recovery review for draft persistence or UI handling

#### Scenario: Scheduler returns review package
- **WHEN** scheduler placement completes
- **THEN** it returns a `ScheduledDraftReview` package with status, scheduled days, unscheduled tasks, risk report, infeasibility options, assumptions, and scheduler trace
- **AND** it does not activate tasks, create Today actions, or mutate the compiler package

#### Scenario: Scheduler preflight uses safe defaults
- **WHEN** the compiler package is ready but optional scheduler anchors are missing
- **THEN** the scheduler defaults missing start date to today, deadline type to assumed when a deadline exists, daily capacity to 60 minutes, existing active load to empty, rest and unavailable dates to empty lists, and buffer policy to standard reservation
- **AND** every default is visible in the scheduled review assumptions or trace

#### Scenario: Missing deadline asks for input
- **WHEN** the scheduler receives a compiler-ready package without a deadline
- **THEN** it returns `needs_input` with one focused deadline or timebox question
- **AND** it does not invent a deadline or create scheduled days

#### Scenario: Scheduler consumes validated tasks
- **WHEN** task candidates pass quality and estimate checks
- **THEN** the scheduler assigns dates using dependency order, daily capacity, existing active load, rest days, unavailable dates, buffer policy, deadline, and deadline type
- **AND** it does not invent new learning content while scheduling

#### Scenario: Empty schedulable task set asks for input
- **WHEN** the compiler-ready package has no schedulable task candidates
- **THEN** the scheduler returns `needs_input` or a validation recovery payload
- **AND** it does not create placeholder tasks

#### Scenario: Scheduler uses inclusive local date window
- **WHEN** start date and deadline are available
- **THEN** the scheduler builds an inclusive local-date window from start date through deadline
- **AND** if the deadline is before the start date it returns `infeasible_review` without placing work after the deadline

#### Scenario: Scheduler preserves dependency order
- **WHEN** tasks have dependencies or predecessors
- **THEN** scheduled dates preserve those ordering constraints unless the draft is explicitly marked infeasible

#### Scenario: Scheduler reports infeasibility as valid output
- **WHEN** the plan cannot fit within the deadline and capacity constraints
- **THEN** the scheduler returns a draft with overload, expected-late, buffer-erosion, or capacity-gap facts
- **AND** it does not silently change target depth, deadline, or user capacity

#### Scenario: Review status is derived from essential work fit
- **WHEN** all essential work is scheduled inside the deadline without unaccepted overload and without unaccepted buffer erosion
- **THEN** the scheduler returns `draft_review`
- **AND** optional or stretch work may remain unscheduled only when that is explicit in the risk report

#### Scenario: Essential work requires user tradeoff
- **WHEN** essential work is late, unscheduled, over capacity, or requires unaccepted buffer, crunch, or overload
- **THEN** the scheduler returns `infeasible_review`
- **AND** it exposes the concrete facts and available options before activation

#### Scenario: Scheduler computes usable capacity
- **WHEN** the scheduler evaluates a date
- **THEN** it computes usable capacity from user capacity, rest-day or unavailable-day state, and existing active plan load
- **AND** it prevents the new draft from consuming every free minute unless the user chooses crunch or overload

#### Scenario: Rest and unavailable days remain visible
- **WHEN** a date is a rest day or unavailable date
- **THEN** the scheduler keeps the date in the review window with zero normal placement capacity
- **AND** it places fallback or reading work there only after explicit user choice

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

#### Scenario: Load-shape tie-breakers are deterministic
- **WHEN** multiple dates can accept the same task under the selected load shape
- **THEN** balanced placement chooses the lowest planned-minutes-to-budget ratio and then earliest date
- **AND** front-loaded placement chooses the earliest valid date
- **AND** light-start caps the first usable day at half budget before using balanced placement

#### Scenario: Load shapes change distribution only
- **WHEN** load shape is balanced, front-loaded, or light-start
- **THEN** the scheduler changes which valid date receives work
- **AND** it never changes scope, dependencies, rest-day rules, hard deadline behavior, or accepted/unaccepted overload state

#### Scenario: Task is split across low-capacity days
- **WHEN** a validated task estimate exceeds the normal planning budget for available days
- **THEN** the scheduler splits it into dated continuation sessions only at approved split points or explicit multi-session boundaries
- **AND** each session keeps the parent task, sequence order, estimated minutes, and visible sub-output or continuation note
- **AND** the scheduler does not place an over-budget single-day task unless the user explicitly accepts crunch or overload

#### Scenario: Unsplittable task cannot fit
- **WHEN** a task cannot be meaningfully split and cannot fit any available day
- **THEN** the scheduler returns expected-late, overloaded-date, or capacity-gap facts
- **AND** the draft enters infeasible review instead of silently creating an unrealistic daily plan

#### Scenario: Split session preserves parent task
- **WHEN** the scheduler creates continuation sessions
- **THEN** each session keeps the parent task id, classification, dependency context, sequence order, session estimate, and visible sub-output
- **AND** the scheduler does not create unrelated new task identities

### Requirement: Buffer And Low-Energy Fallback Scheduling
The system SHALL include buffer and low-energy fallback planning in generated drafts.

#### Scenario: Draft reserves buffer where possible
- **WHEN** the deadline window has enough non-rest days
- **THEN** the draft reserves explicit buffer time before the deadline
- **AND** the buffer is visible in review

#### Scenario: Buffer reservation follows deterministic day count
- **WHEN** there are fewer than three usable normal-placement days
- **THEN** the scheduler reserves zero buffer days and records that no buffer is available
- **AND** when there are three to six usable days it reserves the latest one usable day
- **AND** when there are seven or more usable days it reserves the latest twenty percent of usable days rounded up and clamped to one through five days

#### Scenario: Buffer erosion is visible
- **WHEN** a draft can fit only by consuming planned buffer
- **THEN** the draft marks buffer erosion as a risk
- **AND** the user can choose whether to accept that risk, reduce scope, extend the deadline, or increase capacity

#### Scenario: Buffer erosion blocks feasible status until accepted
- **WHEN** essential work fits only by using reserved buffer
- **THEN** the scheduler may show the buffer-consuming placement
- **AND** the draft remains `infeasible_review` until the user accepts buffer risk or changes constraints

#### Scenario: Capacity gap separates essential and optional work
- **WHEN** essential work and optional or stretch work cannot all fit
- **THEN** the scheduler calculates capacity gap against essential work first
- **AND** optional or stretch unscheduled minutes are reported separately from the essential capacity gap

#### Scenario: Draft exposes fallback mode
- **WHEN** a scheduled day has meaningful work
- **THEN** the draft may include a low-energy fallback for that day
- **AND** the fallback is attached to the day as a reduced execution mode rather than a separate noisy todo
- **AND** the draft explains whether using the fallback preserves momentum, creates follow-up work, or changes risk

#### Scenario: Fallback does not silently complete normal work
- **WHEN** a scheduled item exposes fallback mode
- **THEN** fallback minutes and output are review metadata
- **AND** the scheduler does not count fallback completion as completing the full scheduled item unless a later explicit adjustment converts the plan

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

#### Scenario: Crunch differs from overload
- **WHEN** the user chooses `accept_crunch`
- **THEN** the scheduler may raise selected dates from the 80 percent planning budget up to 100 percent of usable capacity
- **AND** it does not exceed usable capacity

#### Scenario: Overload is explicitly visible
- **WHEN** the user chooses `accept_overload`
- **THEN** the scheduler may place work above usable capacity only on explicitly accepted dates
- **AND** those dates remain marked overloaded in the review package

#### Scenario: Option effect returns review version not activation
- **WHEN** the scheduler applies an infeasibility option effect
- **THEN** it returns a new scheduled review package, a storage state, or a compiler-recompute handoff
- **AND** it does not activate the plan without explicit user confirmation

#### Scenario: Reduce scope preserves target output and depth
- **WHEN** the user chooses `reduce_scope`
- **THEN** the system removes or unschedules stretch work, optional work, optional source sections, secondary modifiers, or excess practice volume before touching essential work
- **AND** it does not remove the minimal completion evidence required by the confirmed target output and target depth

#### Scenario: Lower depth changes obligations visibly
- **WHEN** the user chooses `lower_depth`
- **THEN** the system changes target-depth obligations, regenerates affected phases or tasks, and reschedules into a new draft version
- **AND** the review shows removed or changed evidence, changed minutes, and the new fit or risk state before activation

#### Scenario: Lower depth requires compiler handoff
- **WHEN** `lower_depth` is selected from scheduler review
- **THEN** the scheduler returns a compiler-recompute handoff with requested target depth and current fit facts
- **AND** it does not itself generate replacement task candidates

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
