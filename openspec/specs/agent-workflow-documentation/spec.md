# agent-workflow-documentation Specification

## Purpose
TBD - created by archiving change streamline-agent-workflow-docs. Update Purpose after archive.
## Requirements
### Requirement: Concise Agent Entry File
The repository SHALL keep `AGENTS.md` as a concise entry contract that preserves mandatory project gates and points to detailed workflow documentation.

#### Scenario: Agent entry file is loaded
- **WHEN** an agent reads `AGENTS.md`
- **THEN** it can identify the required design, git safety, implementation, verification, hotfix, and language rules without reading a long manual inline

#### Scenario: Detailed guidance is needed
- **WHEN** an agent needs expanded rationale or step-by-step workflow detail
- **THEN** `AGENTS.md` links to the detailed workflow reference document

### Requirement: Detailed Workflow Reference
The repository SHALL preserve the expanded OpenSpec, git safety, TDD, review, finalization, hotfix, and language guidance in a dedicated documentation file.

#### Scenario: Workflow detail is moved out of AGENTS
- **WHEN** detailed process text is removed from `AGENTS.md`
- **THEN** equivalent guidance remains available in the referenced workflow document

#### Scenario: Project-specific overrides are reviewed
- **WHEN** a contributor reviews the workflow reference
- **THEN** it documents the current-checkout default, worktree exceptions, checkpoint expectations, and manual QA awareness for this desktop app project
