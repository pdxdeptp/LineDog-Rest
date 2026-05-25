## ADDED Requirements

### Requirement: Long-Running Automation Control State
The repository SHALL provide durable control files for long-running automations so the automation prompt, runbook, progress summary, and machine-readable state describe the same checkpoint state machine.

#### Scenario: Product-deepen round count changes
- **WHEN** a long-running automation changes the required number of product-deepen rounds
- **THEN** the local state, runbook, progress summary, and automation prompt MUST all describe the same required round count and next checkpoint

#### Scenario: State machine migration occurs
- **WHEN** an automation control state is migrated from an older checkpoint model to a newer checkpoint model
- **THEN** the migration MUST be recorded in machine-readable evidence and in the human progress log before the automation resumes normal execution

### Requirement: Resumable Apply Checkpoints
The repository SHALL track apply work for long-running automations at independently verifiable task-group granularity.

#### Scenario: Apply is interrupted
- **WHEN** an apply run stops before the full OpenSpec change is complete
- **THEN** the automation state MUST identify the current or next apply task group, the associated task ids, evidence path, verification commands, and completion status

#### Scenario: Apply task group completes
- **WHEN** an apply task group is completed
- **THEN** the automation MUST record fresh test and OpenSpec validation evidence before advancing to the next apply task group

### Requirement: Workspace Safety Baseline
The repository SHALL give long-running automations a workspace safety baseline that distinguishes accepted pre-existing paths from unsafe new or overlapping changes.

#### Scenario: Automation starts with an existing dirty worktree
- **WHEN** a long-running automation begins or resumes while the worktree contains accepted pre-existing changes
- **THEN** the automation MUST compare fresh git status output against the baseline and block only on unsafe new paths, overlapping user changes, or paths outside the current checkpoint ownership

#### Scenario: Automation stages files
- **WHEN** a long-running automation stages files for a checkpoint
- **THEN** it MUST stage only files allowed by the current checkpoint ownership and MUST NOT stage runtime SQLite/WAL/SHM files, DerivedData, screenshots, logs, or unrelated user changes
