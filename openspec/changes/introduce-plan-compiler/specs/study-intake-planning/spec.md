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
- **THEN** the compiler receives a structured envelope containing role, archetype, deadline, deadline type, capacity, target output, target depth, source summaries, existing active load, rest days, source roles, and provenance
- **AND** missing or assumed fields remain explicitly marked

#### Scenario: Compiler returns structured task candidates
- **WHEN** compilation succeeds before deterministic scheduling
- **THEN** the system returns assumptions, phases, milestones, executable task candidates, estimates, fallback modes, split points, calibration, and trace facts
- **AND** final scheduled dates are absent until deterministic scheduling runs

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

#### Scenario: Ambiguous archetype is handled narrowly
- **WHEN** multiple plan archetypes would produce materially different daily work and no signal clearly wins
- **THEN** the compiler returns `needs_input` with one archetype-focused question or creates a low-calibration result with a visible assumption when the difference is low impact
- **AND** it does not generate a mixed plan that combines incompatible daily-work shapes without user confirmation

### Requirement: Structured LLM Output Validation
The system SHALL validate all LLM phase and task outputs against narrow schemas before using them in a draft.

#### Scenario: Phase output is schema-validated
- **WHEN** the LLM generates phases
- **THEN** each phase must include id, title, purpose, essential status, effort range, completion evidence, milestones, and assumptions
- **AND** phases missing observable completion evidence are rejected or repaired

#### Scenario: Task output is schema-validated
- **WHEN** the LLM generates task candidates
- **THEN** each task must include id, phase id, order, action title, concrete output, completion criteria, estimate, confidence, dependencies, normal mode, fallback mode when useful, split points when useful, and assumptions
- **AND** date fields from LLM output are ignored or rejected

#### Scenario: Invalid LLM output has bounded repair
- **WHEN** LLM output fails schema or quality validation
- **THEN** the system may run at most a bounded repair loop
- **AND** unresolved blocking failures return `compile_failed` or `needs_input`
- **AND** unresolved warning-level uncertainty may mark a structurally valid result low-calibration rather than producing a confident plan

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

### Requirement: Task Quality Gates
The system SHALL validate task candidates before scheduling them into a draft.

#### Scenario: Vague task is rejected or repaired
- **WHEN** a task candidate lacks an action verb, concrete output, completion criteria, or executable stopping condition
- **THEN** the compiler rejects or repairs the candidate before scheduling
- **AND** tasks such as "learn LangGraph", "understand agent memory", "work on resume", or "study repo" are not accepted as final executable tasks

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
- **WHEN** low-confidence estimates cover a significant share of essential work
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
