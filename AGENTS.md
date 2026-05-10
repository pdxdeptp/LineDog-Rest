# AI Agent Workflow Rules: OpenSpec + Superpowers Integration

## Core Directive
This project enforces a strict pipeline: **Design (OpenSpec) → Plan Refinement (Superpowers) → Git Isolation → Implementation (TDD + Subagents) → Finalization.** You are equipped with Superpowers skills; they are NOT suggestions — they are mandatory gates.

---

## Phase 0: Design Refinement (before any code)

When a new feature is proposed or you're asked to explore an idea:

1. **`opsx:explore`** — OpenSpec-aware design discussion. Reads existing artifacts, explores the problem space, identifies edge cases. Do NOT skip to code.
2. **`opsx:propose`** — Once direction is clear, generate all OpenSpec artifacts in one step: `proposal.md`, `design.md`, `specs/`, and `tasks.md`.

### Spec Targeting Gate (before `opsx:propose`)

Before creating any OpenSpec change artifacts, the agent MUST resolve which main specs the change modifies.

1. Run `openspec list --specs`.
2. Identify existing spec ids affected by the change.
3. Record them in `proposal.md` under an `Affected Specs` section.
4. Put delta specs under `openspec/changes/<change-name>/specs/<spec-id>/spec.md`, where `<spec-id>` exactly matches the target main spec folder.
5. Only create a new `<spec-id>` when no existing main spec describes the capability.

Archive sync is path-driven: `changes/<change>/specs/<spec-id>/spec.md` merges back to `openspec/specs/<spec-id>/spec.md`. Do not rely on change-name semantics or natural-language guessing for archive targets.

**Gate:** `openspec/changes/<name>/tasks.md` exists before Phase 1 begins.

---

## Phase 1: Git Worktree Isolation (mandatory gate)

**Before any implementation code is written**, you MUST:

1. **`superpowers:using-git-worktrees`** — Create an isolated git worktree on a new branch for this change.
2. **Verify** the test baseline is clean (`xcodebuild test` or `pytest` passes on the worktree) before touching any code.

**Constraint:** Worktree is only required when BOTH conditions are met:
- The main branch has **no uncommitted changes** (working tree clean)
- The task is **new feature development** (not a bug fix)

For bug fixes, or when the main branch has uncommitted changes, work directly in the working directory — no worktree needed.

---

## Phase 2: Subagent-Driven Implementation (with TDD Iron Law)

Entry point is `opsx:apply`. The execution chain is fixed:

```
opsx:apply  →  superpowers:subagent-driven-development  →  (per subagent) superpowers:test-driven-development
```

Never collapse this chain. `opsx:apply` owns the task list; `subagent-driven-development` owns dispatch; `test-driven-development` owns per-task discipline.

### Subagent Dispatch Rules
1. **Analyze for parallelization:** Independent components (separate Swift modules, frontend vs. backend, isolated files) → spawn parallel subagents. Shared files → sequential.
2. **Each subagent** receives only the context it needs: the relevant task from `openspec/changes/<name>/tasks.md`, the relevant `specs/` excerpt, and the target files.
3. **Never** have the main agent write implementation code directly — it orchestrates, reviews, and integrates only.

### The TDD Iron Law (per subagent)
`superpowers:test-driven-development` is invoked at the start of every subagent task. It is NON-NEGOTIABLE:

```
RED   → Write a FAILING test for the assigned component
GREEN → Write the MINIMAL code to make the test pass
REFACTOR → Clean up while tests stay green
```

**If implementation code exists before a failing test exists, the code is deleted.** No exceptions. The test must fail first — a passing test written after the code is not TDD, it's post-hoc validation.

### Two-Stage Review (per subagent)
Each subagent's output goes through automated review:

1. **Spec Compliance Review** — Does the code fulfill `openspec/changes/<name>/specs/` requirements? Are all scenarios covered?
2. **Code Quality Review** — Security, performance, DRY violations, error handling. Critical issues BLOCK progress — the subagent cannot proceed to the next task until critical issues are resolved.

---

## Phase 3: Branch Finalization

When all tasks are complete:

1. **`superpowers:finishing-a-development-branch`** — Verify all tests pass, then present four options:
   - **Merge** the branch into main
   - **Create a GitHub PR** for review
   - **Keep** the branch for later
   - **Discard** everything and clean up
2. Clean up the worktree.

---

## On-Demand Skills (trigger when needed, not every session)

| Skill | When to use |
|-------|------------|
| `superpowers:brainstorming` | Pure divergent ideation with no existing context — use BEFORE entering the OpenSpec flow, not as a replacement for it |
| `superpowers:systematic-debugging` | Bug that isn't obvious from a stack trace — 4-phase root cause: Observe → Hypothesize → Verify → Fix |
| `superpowers:verification-before-completion` | Before declaring any task complete: tests pass + review passed + manual confirmation |
| `superpowers:receiving-code-review` | When a human or another agent provides review feedback — classify by severity and respond systematically |
| `superpowers:requesting-code-review` | When you need a second opinion on a complex change outside the Phase 2 automated review |

---

## Hard Gates (non-negotiable)

- **Skill declaration BEFORE action.** Before invoking any Superpowers skill, announce: 「触发 skill: <skill-name>」. If code is being written without this declaration appearing first, stop and confirm whether the appropriate skill should be invoked.
- **Git worktree BEFORE code.** Never implement on the main branch.
- **Failing test BEFORE implementation.** The TDD Iron Law is enforced — code without a preceding failing test is deleted.
- **Spec compliance review AFTER each task.** Critical issues block the next task.
- **Spec Sync:** If implementation reveals a design flaw, update the OpenSpec `spec.md` before continuing — don't drift from the spec silently.
- **Spec Targeting BEFORE proposal.** Every change must declare affected main spec ids and place delta specs in matching `specs/<spec-id>/` folders before implementation.
- **Parallelism Safety:** Do not dispatch parallel subagents for tasks that touch overlapping files or have strict sequential dependencies.

### Hotfix Exception Channel

All three conditions must be met simultaneously to bypass Phase 0–1:

1. **Scope:** Single file, ≤ 15 lines changed
2. **Type:** Text, comment, config, or copy only — no logic changes
3. **Trigger:** User explicitly uses the word `hotfix` or `trivial` in their request

Even when the exception applies:
- `superpowers:verification-before-completion` is still required
- Tests must still pass before declaring done
- If the fix grows beyond these bounds mid-way, stop and re-enter Phase 0

---

## Language & Reasoning Strategy

- **Reasoning Language:** English (for logical precision with technical docs).
- **Output Language:** Chinese (Standard Mandarin), unless a technical term or code snippet requires English.
- **Implicit Translation:** Think in English, output in Chinese.
