## ADDED Requirements

### Requirement: Coupling Audit

The project SHALL maintain a coupling audit that identifies core architecture hotspots, cites concrete source files, explains why each hotspot is risky, and records the intended refactor direction.

#### Scenario: Audit exists before implementation

- **WHEN** the core-boundary-stabilization change is apply-ready
- **THEN** the repository contains `docs/refactoring/system-coupling-audit.md`
- **AND** the audit lists AppViewModel, WindowManager, settings/defaults, Hermes integration, duplicated watchers or shortcuts, and source-inspection tests as reviewed coupling areas

#### Scenario: Audit remains evidence-based

- **WHEN** a coupling hotspot is added to or updated in the audit
- **THEN** the entry MUST include concrete files or code areas that justify the diagnosis
- **AND** the entry MUST separate observed evidence from proposed refactor direction

### Requirement: Refactor Todo

The project SHALL maintain a prioritized refactor todo that breaks the architecture cleanup into bounded, verifiable tasks.

#### Scenario: Todo orders safe work before risky work

- **WHEN** the refactor todo is reviewed
- **THEN** low-risk duplicate infrastructure tasks MUST appear before AppViewModel or WindowManager extraction tasks
- **AND** each task MUST include status, risk level, target files or modules, and verification expectations

#### Scenario: Todo is updated after each refactor task

- **WHEN** a refactor task is completed
- **THEN** the todo MUST be updated with the completed status and verification evidence
- **AND** any newly discovered coupling or design flaw MUST be reflected in the audit or a follow-up OpenSpec change

### Requirement: Behavior-Preserving Refactor Steps

Each implementation step for this change SHALL preserve existing user-visible behavior unless an existing product capability spec is explicitly updated first.

#### Scenario: Refactor changes code structure only

- **WHEN** a task extracts shared infrastructure or moves responsibility between types
- **THEN** existing behavior MUST remain equivalent for the covered feature
- **AND** focused tests or documented source inspection MUST verify the moved responsibility

#### Scenario: Refactor reveals behavior drift

- **WHEN** implementation reveals that existing behavior is incorrect or underspecified
- **THEN** the relevant OpenSpec capability MUST be updated before the implementation continues
- **AND** the task MUST not silently encode a new product behavior as a refactor

### Requirement: Hermes Boundary Preservation

Hermes-related refactors SHALL preserve Hermes JSON and command contracts as the source of truth.

#### Scenario: Hermes runtime is centralized

- **WHEN** Hermes paths, process execution, decoding, or file watching are centralized
- **THEN** MalDaze MUST continue to read from or invoke the contracted Hermes source
- **AND** MalDaze MUST NOT introduce client-side suppression, optimistic hiding, shadow lists, or local filters to mask backend recalculation

#### Scenario: Hermes failures are surfaced

- **WHEN** a centralized Hermes helper encounters a missing file, invalid JSON, unsupported schema, process failure, or timeout
- **THEN** it MUST preserve or improve the current fail-loud behavior
- **AND** it MUST keep user-facing errors actionable

### Requirement: Test Migration Before High-Risk Extraction

High-risk extraction from AppViewModel, WindowManager, or source-inspection-guarded areas SHALL add stronger behavior or policy coverage before removing source-shape assertions.

#### Scenario: Source-inspection guard blocks refactor

- **WHEN** a refactor would invalidate a test that only checks source-code text
- **THEN** equivalent behavior, policy, or contract coverage MUST be added before the source-shape assertion is removed or weakened

#### Scenario: Window or coordinator boundary is extracted

- **WHEN** AppViewModel or WindowManager responsibilities are moved into a new coordinator or controller
- **THEN** tests MUST cover the extracted decision logic or lifecycle policy
- **AND** manual QA steps MUST be documented for any user-visible window behavior that cannot be fully automated
