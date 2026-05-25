# Failure: Overlapping User Changes Before Apply

- Timestamp: 2026-05-25T04:38:40Z
- Automation: add-initiate-changes
- Change: introduce-study-intake-router
- Checkpoint: introduce-study-intake-router:apply:intake-data-and-idempotency
- Stage: apply preflight
- Category: overlapping_user_changes
- Retryable: false until workspace is reconciled

## Summary

Apply could not start because the workspace contains dirty paths outside the allowed automation baseline. The current checkpoint must not write tests or implementation code from an ambiguous dirty tree.

## Blocking Dirty Paths

- `docs/agent-workflow.md`

## Additional Dirty Paths Not Owned By This Checkpoint

These paths are covered by the existing baseline or previous automation work, but they are not part of the current apply group and were not staged or modified by this preflight:

- `openspec/changes/harden-add-initiate-automation-control/design.md`
- `openspec/changes/harden-add-initiate-automation-control/proposal.md`
- `openspec/changes/harden-add-initiate-automation-control/tasks.md`
- `openspec/changes/redesign-study-intake-planning/iteration-records/round-16-split-readiness-review.md`
- `openspec/changes/redesign-study-intake-planning/pre-split-readiness-audit.md`
- `openspec/changes/redesign-study-intake-planning/split-decision.md`
- `openspec/changes/redesign-study-intake-planning/tasks.md`

## Commands

- `git status --porcelain=v1`: found dirty path outside `workspace-baseline.json`.

## Next Safe Action

Reconcile or intentionally baseline `docs/agent-workflow.md` before resuming apply. Do not start implementation until the pre-apply dirty-tree check is unambiguous and a safe pre-apply checkpoint commit can be created or a structured commit deferral is accepted by the runbook.
