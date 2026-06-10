# High Risk

Use for changes involving Hermes contracts, SSOT rules, persistence migrations, data loss risk, window lifecycle, cross-module architecture, concurrency, app startup, or unclear root cause.

## Steps

1. Run `git status --short --branch` and define the safe isolation strategy.
2. Use OpenSpec before implementation.
3. Use systematic debugging for non-obvious bugs.
4. Create a checkpoint commit or use a worktree when safe and appropriate.
5. Use TDD or a failing reproduction before changing behavior.
6. Run spec compliance and code quality review; critical findings block progress.
7. Run broader verification proportional to blast radius.

## Tooling

- Subagents are appropriate for independent workstreams when the active environment and user request permit delegation.
- Computer Use is appropriate when UI behavior is part of the risk and the user expects agent-side verification.
- Update OpenSpec artifacts if implementation reveals design drift.

## Non-Negotiables

- Never add MalDaze-side shadow state or local fallback logic for Hermes-owned contracts.
- Never duplicate an SSOT fact into profile/defaults/cache without a distinct role.
- Never reset, overwrite, merge, rebase, or discard user work without explicit permission.
