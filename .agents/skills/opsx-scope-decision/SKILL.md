---
name: opsx-scope-decision
description: Decide what belongs in the current OpenSpec change and what should be deferred, split, marked as a non-goal, or rejected. Use after opsx-product-deepen, or whenever new requirements appear during an active change.
---

# opsx:scope-decision

Use this after `opsx:product-deepen` or whenever new ideas, review findings, or user requests appear during an active OpenSpec change.

This is a scope management step. The goal is a change that is independently shippable, reviewable, testable, and not bloated.

## Do Not

- Do not write implementation code.
- Do not modify files unless the user explicitly asks.
- Do not invent new product ideas; classify the ideas already on the table.
- Do not quietly add P1/P2/P3 items to the current change.
- Do not use this as a readiness gate; `opsx:apply-readiness` handles final consistency and implementation-risk checks.

## Inputs

Read:
- `proposal.md`
- `design.md`
- `tasks.md`
- `specs/**/spec.md`
- Relevant existing specs
- Product review notes from `opsx:product-deepen`, if available
- User-provided new requirements or review feedback

If the active change is ambiguous, run `openspec list --json` and ask the user which change to scope.

## Decision Stance

Be opinionated, but do not take product authority away from the user.

Default policy:
- **P0 from product-deepen**: include in the current change unless the user explicitly rejects it.
- **P1**: ask for or require explicit user approval before including in the current change.
- **P2/P3**: defer by default.
- **Non-goal**: add to non-goals only when it prevents likely scope drift.
- **Reject**: discard and explain briefly.

If the user says "you decide," make the smallest safe current-change decision:
- Include P0.
- Defer P1 unless it is tiny and directly required for coherence.
- Defer P2/P3.

## Classification Rules

Classify each idea, issue, or proposed improvement by relationship:
- **Core requirement**: necessary for the primary loop to work.
- **Supporting requirement**: needed to make the primary loop safe, understandable, or testable.
- **Compatibility constraint**: must be documented to avoid breaking existing behavior.
- **Adjacent improvement**: useful but not required for this loop.
- **Future extension**: plausible later proposal.
- **Unrelated**: outside this change.

Then choose exactly one recommendation:
- **Add to current change**
- **Add as small note / compatibility constraint**
- **Defer to follow-up proposal**
- **Mark as non-goal**
- **Reject**

## Split Check

Recommend splitting when the current change contains:
- Multiple unrelated user goals
- Multiple release or review boundaries
- Risky architecture changes mixed with optional UX polish
- Data model, migration, or permission changes mixed with surface polish
- Too many tasks for stable implementation
- Unclear or competing acceptance criteria
- Parallel implementation boundaries that would collide in the same files

If splitting, propose names and boundaries. Do not split mechanically; keep one change when the parts are tightly coupled into one user-visible loop.

## Output

### 1. Current Boundary

- One-sentence change goal
- Included capabilities
- Excluded capabilities
- Primary experience loop or system behavior
- Boundary: coherent / mixed / too broad

### 2. Decision Table

For each item:

| Item | Relationship | Recommendation | Reason | Risk if Deferred | Artifact Impact | Decision |
|------|--------------|----------------|--------|------------------|-----------------|----------|

Keep reasons concise. Do not restate the full product-deepen analysis.

### 3. Split Decision

Choose:
- **Keep as one change**
- **Split change**

If split:
- Proposed change names
- Boundary of each change
- Dependency order

### 4. Minimal Patch Plan

If artifact updates are recommended, list only the smallest required changes:
- `proposal.md`
- `design.md`
- `tasks.md`
- `specs/**/spec.md`
- Non-goals
- Follow-up proposal/backlog note

For each:
- What to add/change
- Why
- Suggested wording, only when useful

### 5. Final Scope Decision

Choose exactly one:
- **KEEP CURRENT SCOPE**
- **ADD SMALL ITEMS THEN CONTINUE**
- **DEFER NEW ITEMS TO FOLLOW-UP**
- **SPLIT CHANGE**
- **REWORK SCOPE BEFORE APPLY**

Then state the next step:
- `opsx:apply-readiness <change>` if scope is settled
- Patch artifacts first if small accepted scope updates remain
- Return to `opsx:product-deepen` only if the underlying product model is still unclear

If this scope decision changes `tasks.md`, `design.md`, or spec deltas, explicitly tell the user that `opsx:apply-readiness` must re-check subagent dispatch boundaries before `opsx:apply`.

## If Asked To Modify Files

Only modify OpenSpec artifacts, never implementation code.

Default write policy:
- Apply approved P0/current-change decisions.
- Apply P1 only when the user explicitly approved it for this round.
- Move deferred items to non-goals or follow-up notes only when useful for preventing scope drift.
- Keep the patch minimal.

After editing, summarize changed files, whether dispatch boundaries must be rechecked, and whether the change should proceed to `opsx:apply-readiness`.
