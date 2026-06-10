# Standard Path

Use for moderate changes with clear scope: user-visible behavior across several files, non-trivial bug fixes, or small features that do not carry high-risk data or architecture concerns.

## Steps

1. Run `git status --short --branch` and identify unrelated user changes.
2. Read the relevant specs, docs, and source files.
3. For new product behavior, create or update an OpenSpec change before implementation.
4. Add a focused test or regression check first when practical.
5. Implement the smallest coherent change.
6. Run focused tests/checks and provide manual QA steps for UI behavior.

## Tooling

- Use OpenSpec when product behavior or documented requirements change.
- Use Computer Use only when the user asks, when UI evidence cannot be obtained otherwise, or when it is much cheaper than asking the user.
- Use subagents only when the user explicitly asks for delegation or when the active tool policy permits it.
- Recommend a checkpoint commit only for multi-step or risky edits; never include unrelated user changes.

## Escalate When

- The change crosses persistence, Hermes contracts, data migration, window lifecycle, or unclear root-cause territory.
- Focused verification is not enough to protect the behavior.
- The user asks the agent to complete end-to-end verification.
