---
name: opsx-apply-readiness
description: Verify that an OpenSpec change is ready for opsx:apply by checking mechanical OpenSpec readiness, artifact consistency, implementation feasibility, task/test coverage, and remaining blockers. Use after scope decisions are settled and before implementation.
---

# opsx:apply-readiness

Use this after scope is settled and before `opsx:apply`, especially for medium or large changes, async workflows, API changes, UI state machines, migrations, or multi-agent implementation.

This is a convergent gate. Do not discover new product opportunities. Do not expand scope unless the current change cannot be implemented safely, coherently, or verifiably without the clarification.

## Do Not

- Do not write implementation code.
- Do not modify files unless the user explicitly asks.
- Do not propose new features or alternative product flows.
- Do not produce a long list of passed checks.
- Do not block on ordinary coding choices that TDD/apply can naturally resolve.

## Inputs

Identify the active change. If ambiguous, run `openspec list --json` and ask the user to choose.

Run:
- `openspec validate --strict <change>`
- `openspec status --change <change> --json`
- `openspec instructions apply --change <change> --json`

Read:
- `proposal.md`
- `design.md`
- `tasks.md`
- `specs/**/spec.md`
- Relevant existing specs or code only when needed to verify feasibility, naming, contracts, or current behavior

## Gate Criteria

Block apply only when a problem would likely cause wrong implementation, failed coordination, unverifiable work, or avoidable rework across workers.

Blocking examples:
- OpenSpec validation fails.
- Status is not apply-ready.
- Proposal/spec/design/tasks contradict each other.
- A design mechanism appears unimplementable or incompatible with the existing code.
- A user-visible failure/cancel/retry/state path is required but missing from specs/tasks.
- A risky migration, API contract, or backward-compatibility behavior is undefined.
- Tasks omit tests for a risky behavior that would otherwise be easy to miss.
- Task dependencies make parallelization unsafe or misleading.

Non-blocking examples:
- Minor implementation choices a worker can decide locally.
- Extra polish ideas.
- Tests for low-risk details already covered by broader tests.
- Refactors unrelated to this change.

## Output

Keep the report short and decision-oriented.

### 1. Decision

Choose exactly one:
- **GO**: ready for `opsx:apply`
- **TUNE THEN GO**: small artifact fixes needed, then apply
- **NO-GO**: unclear, contradictory, or not safely implementable
- **SPLIT FIRST**: too large or mixed for stable implementation

Include one sentence explaining why.

### 2. Mechanical Readiness

Summarize:
- `openspec validate --strict`: pass/fail
- `openspec status`: ready/not ready
- Apply context/tasks available: yes/no

If any fail, include the concrete issue and stop after minimal recommendations.

### 3. Blockers

List only blocking issues. For each:
- Problem
- Evidence from artifact/code
- Minimal required change
- Update target: proposal / design / tasks / spec delta / tests

If there are no blockers, say "No blockers."

### 4. Strong Recommendations

List only high-value non-blocking improvements that would reduce implementation risk. Keep this short. If none, omit this section.

### 5. Test and Acceptance Gaps

List missing tests or manual checks only when they cover risky behavior, error paths, migration, async state, or acceptance criteria that TDD might not infer from current tasks.

Classify each as:
- Blocking
- Strongly recommended
- Optional

### 6. Dispatch Recheck

If `tasks.md`, `design.md`, or spec deltas changed after `opsx:propose`, include dispatch guidance for `opsx:apply`:

- Shared write targets: list shared test files, setup files, app entry points, route registries, project files, common clients, or common view models.
- Parallelization decision: safe to parallelize / must run sequentially / mixed.
- Ownership rule: assign each shared file to exactly one worker, or require sequential execution.

If there are no shared targets, say "No shared dispatch risks found."

### 7. Next Step

Recommend one command/action:
- `opsx:apply <change>` if GO
- "Patch artifacts, then rerun opsx:apply-readiness" if TUNE THEN GO
- "Return to opsx:product-deepen or opsx:scope-decision" if NO-GO or SPLIT FIRST

## If Asked To Modify Files

Only modify OpenSpec artifacts, never implementation code.

Default write policy:
- Apply only minimal changes required to clear blockers.
- Do not add optional improvements.
- Preserve settled scope.

After editing, rerun the mechanical readiness commands and report the final decision.
