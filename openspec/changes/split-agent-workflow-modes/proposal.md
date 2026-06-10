## Why

The current agent workflow still pushes small fixes through a heavyweight default path. We need `AGENTS.md` to stay compact and route agents to the lightest safe workflow instead of loading every detailed mode up front.

## What Changes

- Turn `AGENTS.md` into a concise workflow router with a fast default path and explicit escalation triggers.
- Add small, separately loaded mode files under `docs/agent-modes/`.
- Keep expanded rationale and legacy process detail in `docs/agent-workflow.md`.
- Make Computer Use, subagents, OpenSpec apply, and checkpoint commits opt-in or risk-triggered instead of default for every task.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `agent-workflow-documentation`: agent workflow documentation must support mode-specific files that are read on demand, with `AGENTS.md` acting as a concise router.

## Affected Specs

- `agent-workflow-documentation`

## Impact

- Affected docs: `AGENTS.md`, `docs/agent-workflow.md`, new `docs/agent-modes/*.md`.
- Affected OpenSpec: `openspec/specs/agent-workflow-documentation/spec.md` delta.
- No application runtime, Hermes contract, persistence, or build-system impact.
