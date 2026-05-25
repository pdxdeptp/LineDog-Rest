## ADDED Requirements

### Requirement: Intake And Draft Lifecycle State Machine
The system SHALL model Add / Initiate as an explicit lifecycle from idle through routing, review, compilation, draft review, activation, cancellation, or storage.

#### Scenario: Item moves through routing and role review
- **WHEN** the user submits an item
- **THEN** the item moves from `idle` to `intake_submitted`, `routing`, and `role_review`
- **AND** no active tasks are created during these states

#### Scenario: Non-plan item exits planning safely
- **WHEN** the user confirms a reference, later, or material-only role
- **THEN** the item moves to `stored_non_plan`
- **AND** it remains excluded from Today and active scheduling

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

#### Scenario: Plan draft package is versioned
- **WHEN** the compiler returns or updates a draft package
- **THEN** the package includes schema version, draft id, draft version, intake id, status, summary, assumptions, review summary, and activation eligibility
- **AND** status-specific plan, schedule, risk, missing-input, or validation fields follow the package status

#### Scenario: Blocked draft package includes recovery details
- **WHEN** the compiler returns `needs_input` or `compile_failed`
- **THEN** the package includes missing facts or validation errors plus recovery actions
- **AND** it does not require complete phases, tasks, schedule, or risk report

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

### Requirement: Low-Energy Fallback Completion
The system SHALL treat fallback completion as partial progress rather than full task completion.

#### Scenario: Fallback completion does not fake full completion
- **WHEN** the user later completes only the low-energy fallback for a planned task
- **THEN** the system records partial progress or adjustment need
- **AND** it does not mark the full task complete unless the full task was completed

#### Scenario: Fallback completion keeps follow-up visible
- **WHEN** only fallback mode is completed for a scheduled task
- **THEN** the system records fallback completion time and actual minutes when available
- **AND** the full task remains incomplete with `needs_followup`
- **AND** later rollover or adjustment logic can still account for the remaining work
