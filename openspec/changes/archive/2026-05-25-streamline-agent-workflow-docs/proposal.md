## Why

`AGENTS.md` currently contains the full agent workflow manual inline, making the entry instruction file long and harder to scan. Condensing the entry file while preserving the detailed workflow elsewhere keeps agent context lean without losing project-specific guardrails.

## Affected Specs

- New spec: `agent-workflow-documentation`

## What Changes

- Shorten `AGENTS.md` to a compact, hard-gate oriented project contract.
- Move the detailed OpenSpec, git safety, TDD, review, hotfix, and finalization guidance into a dedicated reference document under `docs/`.
- Cross-link the compact entry file to the detailed workflow reference.
- Preserve the existing requirements, including spec targeting, current-checkout default workflow, manual QA awareness, and output-language expectations.

## Capabilities

### New Capabilities
- `agent-workflow-documentation`: Defines how project-level agent instructions are split between the concise entry file and detailed workflow reference.

### Modified Capabilities
- None.

## Impact

- Affected files: `AGENTS.md`, `docs/agent-workflow.md`, and this OpenSpec change directory.
- No app runtime code, user-facing UI, APIs, dependencies, or data models change.
