## ADDED Requirements

### Requirement: User-Owned Value And Depth Decisions
The system SHALL keep value judgment and target-depth selection under user control for first-version intake.

#### Scenario: System does not judge whether goal is worth doing
- **WHEN** the user submits a goal or resource
- **THEN** the compiler may show estimated cost, calibration, and plan risk
- **AND** it does not independently reject or prioritize the item based on whether it is worth learning

#### Scenario: Target depth changes completion obligations
- **WHEN** the user selects skim/orientation, can-use, project-level, interview-ready, or source-understanding depth
- **THEN** the draft changes required completion evidence and task families to match that depth
- **AND** the draft does not treat depth as a display-only label

### Requirement: Minimal Planning Anchors
The system SHALL collect or assume the minimum anchors needed for a deadline-driven draft plan.

#### Scenario: Required anchors are present
- **WHEN** the item has a deadline, available time, target output, and target depth
- **THEN** the compiler can generate a plan structure without additional questions

#### Scenario: One or two anchors are missing
- **WHEN** the item is missing target output, target depth, deadline, or available time
- **THEN** the compiler asks the smallest number of questions needed or uses visible recommended assumptions
- **AND** every assumption is displayed in the draft review package

### Requirement: Plan Compiler Contract
The system SHALL generate plan drafts through a staged compiler rather than a single prompt that directly returns a calendar.

#### Scenario: Compiler receives normalized envelope
- **WHEN** the user confirms that an item should become a new plan or an attachment to an existing plan with scheduled work
- **THEN** the compiler receives a structured envelope containing draft id, draft version, intake id, draft kind, target plan id when applicable, confirmed role, attachment mode, deadline, deadline type, capacity, target output, target depth, source summaries, source roles, existing-plan context when applicable, and provenance
- **AND** missing or assumed fields remain explicitly marked

#### Scenario: Compiler returns structured task candidates
- **WHEN** compilation succeeds before deterministic scheduling
- **THEN** the system returns assumptions, phases, milestones, executable task candidates, estimates, fallback modes, split points, calibration, and trace facts
- **AND** final scheduled dates are absent until deterministic scheduling runs

#### Scenario: Compiler status is not scheduler status
- **WHEN** the compiler completes before deterministic scheduling
- **THEN** it returns `draft_review`, `needs_input`, or `compile_failed`
- **AND** it does not return `infeasible_review`, capacity-gap facts, overloaded dates, or final schedule risk

#### Scenario: Blocked compiler result has recovery details
- **WHEN** compilation returns `needs_input` or `compile_failed`
- **THEN** the result includes missing facts or validation errors plus recovery actions
- **AND** complete phases and task candidates are not required for those blocked statuses

#### Scenario: LLM does not own date placement
- **WHEN** LLM-generated decomposition includes suggested dates
- **THEN** the system treats those dates as non-authoritative
- **AND** final scheduled dates are assigned only by deterministic scheduling logic

### Requirement: Archetype And Scope Selection
The compiler SHALL select one primary plan archetype and a scope boundary before task generation.

#### Scenario: Archetype selection uses explicit signals
- **WHEN** the compiler selects an archetype
- **THEN** it uses confirmed intake role, attachment mode, source roles, target output, target depth, source type, existing-plan context, and user constraints as selection inputs
- **AND** it records the selected primary archetype, secondary modifiers, included or excluded materials, confidence, and visible assumptions

#### Scenario: Archetype tie-breakers are deterministic
- **WHEN** source type, user wording, source role, target output, target depth, and existing-plan attachment imply different archetypes
- **THEN** the compiler applies documented tie-breakers where explicit target output beats source type, target depth beats generic learning wording, confirmed source role beats URL shape, and existing-plan draft kind beats new-plan archetypes
- **AND** it records the tie-breaker or returns `needs_input` when materially different daily-work shapes remain unresolved

#### Scenario: Ambiguous archetype is handled narrowly
- **WHEN** multiple plan archetypes would produce materially different daily work and no signal clearly wins
- **THEN** the compiler returns `needs_input` with one archetype-focused question or creates a low-calibration result with a visible assumption when the difference is low impact
- **AND** it does not generate a mixed plan that combines incompatible daily-work shapes without user confirmation

### Requirement: Source And Goal Synopsis
The compiler SHALL build a compact source and goal synopsis before asking an LLM to generate phases or task candidates.

#### Scenario: Synopsis uses target output first
- **WHEN** the compiler summarizes an item for phase or task generation
- **THEN** the synopsis includes the user target output, target depth, source role, useful source facts, unknowns, material references, and estimate facts
- **AND** it does not blindly mirror every source chapter, file, or note as a task

#### Scenario: Thin source facts affect calibration
- **WHEN** the selected archetype requires source facts that are missing or too thin
- **THEN** the compiler returns `needs_input` with one focused question or marks an otherwise valid result low-calibration
- **AND** it does not invent precise source structure from a URL or title alone

### Requirement: Structured LLM Output Validation
The system SHALL validate all LLM phase and task outputs against narrow schemas before using them in a draft.

#### Scenario: Phase output is schema-validated
- **WHEN** the LLM generates phases
- **THEN** each phase must include id, title, purpose, essential status, effort range, completion evidence, milestones, and assumptions
- **AND** phases missing observable completion evidence are rejected or repaired

#### Scenario: Task output is schema-validated
- **WHEN** the LLM generates task candidates
- **THEN** each task must include id, phase id, order, work type, essential/optional/stretch classification, action title, concrete output, completion criteria, estimate, confidence, dependencies, normal mode, fallback mode when useful, split points when useful, depth-obligation or reducible reason, and assumptions
- **AND** date fields from LLM output are ignored or rejected

#### Scenario: Invalid LLM output has bounded repair
- **WHEN** LLM output fails schema or quality validation
- **THEN** the system may run at most a bounded repair loop
- **AND** unresolved blocking failures return `compile_failed` or `needs_input`
- **AND** unresolved warning-level uncertainty may mark a structurally valid result low-calibration rather than producing a confident plan

#### Scenario: Repair cannot change user anchors
- **WHEN** the compiler repairs invalid phase or task output
- **THEN** the repair may fix only cited schema or quality failures
- **AND** it must not change user-provided anchors, target depth, deadline type, source role, selected existing plan, or final scheduled dates

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
- **THEN** the task includes action title, concrete output, completion criteria, work type, essential/optional/stretch classification, estimated minutes, dependency or predecessor, phase link, normal mode, fallback mode when useful, split points when a task may span sessions, confidence, depth-obligation or reducible reason, and assumptions
- **AND** source or material references are attached when applicable

#### Scenario: Task candidates are not scheduled by the LLM
- **WHEN** task candidates are created
- **THEN** they are ordered by dependency and phase
- **AND** they do not become dated daily tasks until deterministic scheduling runs

### Requirement: Task Quality Gates
The system SHALL validate task candidates before scheduling them into a draft.

#### Scenario: Vague task is rejected or repaired
- **WHEN** a task candidate lacks an action verb, concrete output, completion criteria, executable stopping condition, work type, or essential/optional/stretch classification
- **THEN** the compiler rejects or repairs the candidate before scheduling
- **AND** tasks such as "learn LangGraph", "understand agent memory", "work on resume", or "study repo" are not accepted as final executable tasks

#### Scenario: Out-of-scope material is rejected or repaired
- **WHEN** a task candidate references material outside the selected scope boundary
- **THEN** the compiler rejects or repairs the candidate
- **AND** it does not expand the plan to cover extra materials without explicit user confirmation

#### Scenario: Oversized task is split
- **WHEN** a task candidate is estimated over the configured large-task threshold
- **THEN** the compiler splits it at meaningful checkpoints or marks it as a multi-session milestone
- **AND** it does not hand an oversized ordinary task to the scheduler without split points or explicit multi-session handling

### Requirement: Estimate Normalization
The system SHALL normalize task estimates before scheduling.

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
- **WHEN** low-confidence estimates cover at least 30% of essential estimated minutes, three or more essential tasks use default-only estimates, source-understanding or rebuild scope lacks sufficient source facts, or conflicting anchors require visible assumptions
- **THEN** the result is marked low-calibration with visible rough-estimate assumptions
- **AND** activation later requires explicit user confirmation or estimate edits

### Requirement: Compiler Trace And Observability
The system SHALL expose implementation-facing compiler trace facts for tests and debugging without exposing sensitive raw content or hidden reasoning.

#### Scenario: Compiler records validation and estimate trace
- **WHEN** the compiler creates, repairs, or rejects a draft structure
- **THEN** the trace records envelope fact provenance, selected archetype, schema validation results, repair attempt count, task quality gate outcomes, estimate normalization decisions, and low-calibration reasons
- **AND** trace records are sufficient for contract tests to explain why a draft structure was low-calibration or rejected

#### Scenario: Trace avoids sensitive raw content
- **WHEN** the input contains resume text, interview prep, private project notes, private repo descriptions, or Obsidian snippets
- **THEN** trace records redact or summarize sensitive raw text
- **AND** they do not expose raw prompts or hidden chain-of-thought in user-facing UI

### Requirement: Sensitive Planning Input Boundary
The compiler SHALL limit sensitive planning content to the submitted item, confirmed anchors, selected material references, and upstream shallow source facts.

#### Scenario: Compiler does not silently broaden private context
- **WHEN** the compiler handles private project notes, resume material, interview prep notes, private repo descriptions, or Obsidian snippets
- **THEN** it uses only selected or submitted content and shallow upstream facts
- **AND** it does not silently read unrelated Obsidian vault content, unrelated repo files, or broader local context

#### Scenario: LLM call receives bounded content
- **WHEN** an LLM call is used for phases, tasks, or repair
- **THEN** the prompt contains only the minimal synopsis, relevant snippets, selected material references, schemas, and failed fields needed for that call
- **AND** prompt logs, trace records, and validation errors redact or summarize sensitive raw text

### Requirement: Real-Context Compiler Fixtures
The compiler SHALL be verifiable against the user's real planning objects before scheduler implementation.

#### Scenario: AgentGuide compiler fixture
- **WHEN** the input is AgentGuide as a main learning object with project-level or interview-ready depth
- **THEN** the compiler selects `finite_learning_project`, may add `interview_notes`, and produces phases for orientation, guided reproduction, small demo, and interview notes or review
- **AND** task candidates include concrete evidence such as setup notes, a runnable guide example, a small tool-calling demo, or a 6-bullet agent-loop explanation

#### Scenario: easyagent compiler fixture
- **WHEN** the input is easyagent as a rebuild or clone target with source-understanding depth
- **THEN** the compiler selects `rebuild_or_clone` and produces tasks for source map, quickstart or baseline notes, call-flow trace, runnable minimal loop, one modification, and architecture explanation
- **AND** thin repo facts mark the package low-calibration or produce one `needs_input` question rather than invented precise source structure

#### Scenario: LeetCode compiler fixture
- **WHEN** the input is LeetCode Hot 100 or 灵茶山基础精炼
- **THEN** the compiler selects `recurring_practice`
- **AND** task candidates cover diagnostic, practice blocks, mistake tagging, spaced redo, checkpoint mock sets, and recall sheets instead of course-like chapters

#### Scenario: Interview prep compiler fixture
- **WHEN** the input is agent or backend interview prep
- **THEN** the compiler selects `topic_review_cycle`
- **AND** task candidates include answer batches, project-linked examples, mock explanation, gap notes, and spaced review

#### Scenario: Resume packaging compiler fixture
- **WHEN** the input is resume or project packaging work
- **THEN** the compiler selects `project_packaging`
- **AND** task candidates include evidence inventory, impact-first bullet variants, project story draft, rehearsal gaps, and revision

#### Scenario: Compiler fixtures are unscheduled
- **WHEN** any real-context compiler fixture succeeds
- **THEN** the output contains phases, task candidates, estimates, calibration, and trace
- **AND** it contains no final scheduled dates, capacity-gap math, buffer erosion, overloaded dates, or `infeasible_review`
