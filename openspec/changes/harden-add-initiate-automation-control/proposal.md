## Why

The Add / Initiate implementation automation is expected to run for hours across multiple OpenSpec changes, but its prompt, local state, runbook, and recovery records can diverge. This change hardens the automation control plane so long-running work can resume from durable checkpoints instead of relying on chat memory or ambiguous progress text.

## What Changes

- Align the authoritative control files with three product-deepening rounds before apply.
- Record an explicit migration from the earlier two-round state machine to the three-round state machine.
- Add resumable apply task-group tracking so an interrupted apply run can identify the next independently verifiable group.
- Add a workspace safety baseline and overlap policy so the automation can distinguish accepted pre-existing changes from unsafe new or overlapping changes.

## Capabilities

### New Capabilities

### Modified Capabilities

- `agent-workflow-documentation`: add requirements for durable automation control state, migration evidence, resumable apply checkpoints, and workspace safety baselines.

## Impact

- Affects `openspec/add-initiate-implementation-control/state.json`, `runbook.md`, `progress.md`, and new evidence/control files under that directory.
- Affects automation `add-initiate-changes` prompt so it follows the same state machine as the local control files.
- Does not change product behavior or application runtime code.
