# Full Delivery

Use when the user explicitly asks for end-to-end completion, full QA, "you verify it", or when collaborating in a vibe-coding loop where the agent is expected to drive the app.

## Steps

1. Run `git status --short --branch` and protect unrelated user work.
2. Use OpenSpec for new product behavior or substantial design changes.
3. Prefer TDD or an explicit regression check before implementation.
4. Implement, then run focused automated checks.
5. Launch or attach to the relevant app when useful.
6. Use Browser or Computer Use for UI verification when it provides real evidence.
7. Report exact checks, UI verification performed, and residual manual QA needs.

## Defaults

- Computer Use is allowed in this mode, but still avoid low-value UI driving.
- Checkpoint commits are recommended for long or risky runs, especially in dirty worktrees.
- Broader tests are appropriate when the change touches shared surfaces.

## Stop Or Ask When

- UI actions would transmit sensitive data, delete data, change account permissions, or alter system settings.
- The app state cannot be verified without user credentials or physical judgment.
- Verification would disturb unrelated user work more than it helps.
