---
name: opsx-product-deepen
description: Deepen an existing OpenSpec change after opsx:propose and before opsx:apply by finding product, UX, workflow, state, edge-case, and model gaps that should be clarified before implementation. Use for non-trivial changes or when the user wants a pre-apply product/experience review.
---

# opsx:product-deepen

Use this after `opsx:propose` when a change feels product-heavy, multi-step, async, cross-platform, user-visible, or otherwise too large to trust from a single proposal pass.

This is a divergent review, but it is not a license to expand scope. The goal is to surface gaps that would make `opsx:apply` ambiguous, brittle, or likely to implement the wrong user experience.

## Do Not

- Do not write implementation code.
- Do not modify files unless the user explicitly asks.
- Do not treat every good idea as part of the current change.
- Do not promote P1/P2 ideas into the current change without explicit user approval.
- Do not list ordinary implementation bugs unless they reveal a missing requirement, task, state transition, or acceptance criterion.

## Inputs

Read the active change artifacts:
- `proposal.md`
- `design.md`
- `tasks.md`
- `specs/**/spec.md`

Also read, only as needed:
- Relevant existing specs in `openspec/specs/`
- Relevant existing code to validate feasibility, naming, or current behavior

If the change is ambiguous, run `openspec list --json` and ask the user which change to review.

## Review Stance

Ask: "What must be made explicit before TDD/apply so that implementation workers do not guess?"

Prefer issues about:
- User intent and entry point clarity
- Waiting/loading/processing feedback
- Review before commit
- Cancel, retry, rollback, and failure behavior
- Defaults and first-run behavior
- State consistency across async operations
- API/input/output contracts
- Persistence, migration, and backward compatibility
- Security, privacy, permissions
- Future extensibility risks that would block the current model
- Testability and observability for risky behavior

## Scope Classification

Classify every finding:

- **P0**: Must address before apply. Current docs are unsafe, contradictory, unimplementable, or unverifiable without this.
- **P1**: Strong candidate for this change, but requires explicit user approval because it changes scope or adds meaningful work.
- **P2**: Useful but optional. Do not include by default.
- **P3**: Future proposal/backlog. Should not enter this change.
- **Non-goal**: Should be explicitly excluded to prevent scope drift.
- **Reject**: Not worth doing.

If the user says "you decide" without a specific scope rule, update or recommend only P0 for the current change. Report P1 separately for user choice.

## Output

### 1. Change Understanding

- Problem this change solves
- Intended user/system experience loop
- Explicit non-goals
- Whether the current boundary is clear

### 2. Experience Loops

List only the loops relevant to implementation risk. For each:
- Name
- Goal
- Entry/trigger
- Main path
- Success state
- Failure state
- Cancel/exit/rollback state
- User-visible or operator-visible feedback
- Acceptance criteria
- Coverage: complete / partial / missing

### 3. Deep Issues

Lead with P0/P1. Keep the list focused; avoid filler.

For each issue:
- Priority
- Problem
- Why it matters
- Suggested direction
- Suggested destination: proposal / design / tasks / spec delta / non-goal / future proposal / reject
- Scope impact

### 4. Product Model Review

Briefly check:
- Concepts introduced or modified
- Whether names match user-visible concepts
- Whether defaults are justified
- Hidden assumptions
- Whether the model blocks likely near-term improvements

### 5. Recommended Next Actions

Group recommendations:
- Must address before apply
- Needs user scope decision
- Future proposals
- Explicit non-goals
- Reject / not worth doing

If there are no P0 issues, say so plainly. Do not invent blockers.

## If Asked To Modify Files

Only modify OpenSpec artifacts, never implementation code.

Default write policy:
- Apply P0 changes.
- Do not apply P1 changes unless the user explicitly approved P1 for this round.
- Put P2/P3 into future proposals, backlog, or non-goals only if the user asks.

After editing, summarize the exact files changed and whether the change is ready for `opsx:scope-decision` or `opsx:apply-readiness`.
