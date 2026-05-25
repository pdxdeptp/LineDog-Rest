## ADDED Requirements

### Requirement: Add Initiate Async Feedback And Recovery
The system SHALL expose stage-level progress and recovery paths during routing, preview, compilation, scheduling, and activation.

#### Scenario: Thin orchestration adapter preserves ownership
- **WHEN** Add / Initiate advances from route review to anchor review, compilation, scheduling, option effects, storage, or activation
- **THEN** it calls the completed router, draft persistence, compiler, scheduler, and activation helpers through a thin orchestration adapter
- **AND** the adapter does not introduce new routing heuristics, new task-generation logic, new scheduling math, or new activation semantics

#### Scenario: Progress stages are visible
- **WHEN** Add / Initiate processing is running
- **THEN** the UI can show stages such as analyzing input, routing item, previewing source, anchor review, generating phases, generating tasks, validating tasks, scheduling, and preparing review

#### Scenario: Preview or generation failure is recoverable
- **WHEN** material preview, LLM generation, validation, or scheduling cannot complete normally
- **THEN** the user can retry, simplify input, answer one question, continue manually when safe, store for later, or cancel

#### Scenario: Needs input preserves session context
- **WHEN** Add / Initiate needs one more deadline, depth, scope, estimate, or source clarification
- **THEN** the session keeps the submitted input, confirmed role, anchors, assumptions, draft id when present, and previous review facts
- **AND** the user answers only the focused missing item before generation resumes

#### Scenario: Option effect is not activation
- **WHEN** the user selects an infeasibility option such as lowering depth, reducing scope, extending deadline, increasing capacity, accepting crunch, accepting overload, accepting buffer risk, or storing for later
- **THEN** the system returns a new review package, storage state, compiler-recompute handoff, or needs-input state
- **AND** it does not activate active tasks until the user confirms a latest-version review draft

#### Scenario: Activation failure preserves draft
- **WHEN** plan activation fails
- **THEN** the current draft version remains intact
- **AND** the user can retry activation without recreating the plan from scratch

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

#### Scenario: Summary preserves schedule risk facts
- **WHEN** the system renders the compact draft summary
- **THEN** it shows buffer reservation or erosion, low-energy fallback summary, capacity gap, overloaded dates, expected-late tasks, and existing-load conflicts when those facts exist
- **AND** it does not hide accepted overload or accepted buffer risk after the user chooses those options

#### Scenario: Latest draft version gates activation
- **WHEN** the user activates a draft
- **THEN** the activation request references the latest draft id and version known to the review state
- **AND** stale draft versions are rejected without writing active tasks

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

#### Scenario: Draft does not create today action
- **WHEN** a generated plan is still in draft review
- **THEN** no task from that draft appears in Today
- **AND** no smart suggestion is triggered from that draft

#### Scenario: Storage and attachment are quiet
- **WHEN** an Add / Initiate item is stored for later, stored as reference, or attached as material-only support
- **THEN** it may appear in the relevant resource or material list
- **AND** it does not appear in Today, active Calendar load, deadline-risk alerts, or smart-mode proposal triggers

#### Scenario: Confirmed plans drive Today
- **WHEN** the user opens Today
- **THEN** Today contains tasks from confirmed active plans only
- **AND** it excludes references, later resources, and unconfirmed drafts
