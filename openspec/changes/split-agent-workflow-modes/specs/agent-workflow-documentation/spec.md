## MODIFIED Requirements

### Requirement: Concise Agent Entry File
The repository SHALL keep `AGENTS.md` as a concise entry contract that preserves mandatory project invariants, routes agents to the lightest safe workflow mode, and points to detailed workflow documentation without inlining every mode.

#### Scenario: Agent entry file is loaded
- **WHEN** an agent reads `AGENTS.md`
- **THEN** it can identify mandatory invariants such as Hermes SSOT, user-work protection, language rules, and skill declaration rules
- **AND** it can choose between fast, standard, full-delivery, and high-risk workflow modes without reading all mode details inline

#### Scenario: Detailed guidance is needed
- **WHEN** an agent needs expanded rationale or step-by-step workflow detail
- **THEN** `AGENTS.md` links to the detailed workflow reference document
- **AND** `AGENTS.md` links to mode-specific files that can be read on demand

## ADDED Requirements

### Requirement: Mode-Specific Workflow Files
The repository SHALL document each workflow mode in a small dedicated file so agents can read only the selected mode's operating rules.

#### Scenario: Fast path is selected
- **WHEN** a task is a small, clear fix or polish pass
- **THEN** the agent reads `docs/agent-modes/fast-path.md`
- **AND** the agent does not need to load the standard, full-delivery, or high-risk mode files

#### Scenario: Full delivery is explicitly requested
- **WHEN** the user asks for end-to-end completion, full QA, or vibe coding
- **THEN** the agent reads `docs/agent-modes/full-delivery.md`
- **AND** UI automation such as Computer Use can be used as part of verification when useful

#### Scenario: Risk requires escalation
- **WHEN** a task involves persistence migration, Hermes contract changes, data-loss risk, window lifecycle, unclear root cause, or cross-module architecture
- **THEN** the agent escalates from the fast path and reads the appropriate higher-rigor mode file
