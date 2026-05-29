# Agent Workflow Reference

This document preserves the detailed workflow that used to live inline in `AGENTS.md`. Keep `AGENTS.md` as the short entry contract, ideally under 60 lines, and update this file when process detail, rationale, or examples need more space.

## Core Directive

This project follows a strict pipeline:

`Design (OpenSpec) -> Plan Refinement (Superpowers) -> Git Safety Check -> Implementation (TDD + Subagents) -> Finalization`

Superpowers skills are mandatory gates when they apply. They are not optional suggestions.

## Phase 0: Design Refinement

When a new feature is proposed or an idea needs exploration:

1. Run `opsx:explore`.
   - Use OpenSpec-aware design discussion.
   - Read existing artifacts when relevant.
   - Explore edge cases and integration points.
   - Do not write implementation code.
2. Run `opsx:propose` once the direction is clear.
   - Generate `proposal.md`, `design.md`, `specs/`, and `tasks.md`.
   - `openspec/changes/<change>/tasks.md` is the gate before implementation begins.

### Spec Targeting Gate

Before creating OpenSpec change artifacts:

1. Run `openspec list --specs`.
2. Identify existing spec ids affected by the change.
3. Record them in `proposal.md` under an `Affected Specs` section.
4. Put delta specs under `openspec/changes/<change>/specs/<spec-id>/spec.md`, where `<spec-id>` exactly matches the target main spec folder.
5. Create a new `<spec-id>` only when no existing main spec describes the capability.

Archive sync is path-driven: `changes/<change>/specs/<spec-id>/spec.md` merges back to `openspec/specs/<spec-id>/spec.md`. Do not rely on change-name semantics or natural-language guessing for archive targets.

### Soft Pre-Apply Guidance

After `opsx:propose`, do not push straight to `opsx:apply` as the only next step. Offer a short choice:

- Lightweight path: run pre-apply planning for `<change>` before implementation.
- Full pre-apply path: run `opsx:product-deepen <change>` -> `opsx:scope-decision <change>` -> pre-apply planning for `<change>`.
- Pause: leave the change ready for later review or manual edits.
- Direct apply: proceed only if the user explicitly wants to skip pre-apply review.

Recommend the full path for medium or large changes, user-visible behavior, async work, multi-agent work, data writing, or cross-module changes. The lightweight path is acceptable for small, well-bounded changes.

## Phase 1: Git Safety And Manual QA

This desktop-pet project often needs manual verification in the running app. Work directly in the current project directory by default.

Before implementation:

1. Run `git status`.
2. Identify existing user changes.
3. Avoid touching overlapping files unless the user explicitly approves.
4. For large, risky, or multi-step changes, recommend or create a checkpoint commit when appropriate.
5. Before non-worktree `opsx:apply`, create a checkpoint commit when safe.
6. Never include unrelated user changes in a checkpoint commit without approval.

Default workflow:

1. Work in the current project directory.
2. Keep changes scoped to the requested feature, fix, or OpenSpec task.
3. Run relevant automated checks.
4. Ask the user to manually verify UI/UX behavior in the running desktop app when visual or interaction behavior changes.
5. Commit or prepare changes only after implementation and verification, unless the user requests an earlier checkpoint.

### When To Use A Worktree

Use `superpowers:using-git-worktrees` only when:

- The user explicitly asks for a worktree.
- Multiple unrelated features must be developed in parallel.
- A risky experiment should be isolated from the current working directory.
- The current directory must remain on a stable `main` branch for comparison.
- The task does not require frequent manual verification in the running local app.

If a worktree is used, tell the user before implementation:

1. The worktree path.
2. The branch name.
3. The exact command and directory to launch the app for preview.

## Phase 2: Subagent-Driven Implementation

The entry point is `opsx:apply`. The execution chain is fixed:

`opsx:apply -> superpowers:subagent-driven-development -> per-subagent superpowers:test-driven-development`

`opsx:apply` owns the task list. `subagent-driven-development` owns dispatch. `test-driven-development` owns per-task discipline.

### Dispatch Rules

1. Analyze for parallelization.
   - Independent components can run in parallel.
   - Shared files or strict dependencies run sequentially.
2. Give each subagent only the relevant task, spec excerpt, and target files.
3. The main agent orchestrates, reviews, and integrates; subagents write implementation code.

System note: if the active environment does not permit spawning subagents unless the user explicitly asks for them, follow the higher-priority environment rule and document the deviation.

### Pre-Apply Dispatch Recheck

If `opsx:product-deepen`, `opsx:scope-decision`, or pre-apply planning changes `tasks.md`, `design.md`, or spec deltas before implementation:

- Re-read the final `tasks.md`.
- Identify shared write targets, especially shared test files, setup files, app entry points, route registries, project files, clients, and view models.
- Do not dispatch parallel subagents for tasks that modify the same file or same test surface.
- If implementation tasks share test or setup files, run sequentially or assign the shared file to exactly one worker.
- When in doubt, choose sequential execution.

### TDD Iron Law

Each implementation task follows:

`RED -> GREEN -> REFACTOR`

- RED: write a failing test for the assigned behavior.
- GREEN: write the minimal implementation to pass.
- REFACTOR: clean up while tests stay green.

If implementation code exists before a failing test exists, delete the code and restart from RED. A passing test written after implementation is post-hoc validation, not TDD.

Configuration, copy-only, and documentation-only changes may not have meaningful production-code tests. In those cases, still run the best available verification commands and document why TDD does not apply.

### Two-Stage Review

Each task output receives:

1. Spec compliance review.
   - Does the code fulfill `openspec/changes/<change>/specs/` requirements?
   - Are all scenarios covered?
2. Code quality review.
   - Check security, performance, duplication, error handling, and maintainability.
   - Critical issues block progress.

If implementation reveals a design flaw, update the OpenSpec delta before continuing.

## Phase 3: Finalization

When all tasks are complete:

1. Run `superpowers:verification-before-completion`.
2. Verify relevant tests and checks pass.
3. Confirm review passed or list remaining review gaps.
4. Communicate manual QA needs or results for UI/UX changes.
5. Present next-step options:
   - Commit completed changes.
   - Create a GitHub PR for review.
   - Keep changes uncommitted for further manual testing.
   - Discard changes only by explicit user request.
6. If a worktree was used, run `superpowers:finishing-a-development-branch` and clean up the worktree after the user chooses the finalization path.

## On-Demand Skills

| Skill | When to use |
| --- | --- |
| `superpowers:brainstorming` | Pure divergent ideation with no existing context; use before OpenSpec, not instead of it. |
| `superpowers:systematic-debugging` | Non-obvious bugs; follow Observe -> Hypothesize -> Verify -> Fix. |
| `superpowers:verification-before-completion` | Before declaring any task complete. |
| `superpowers:receiving-code-review` | When a human or another agent provides review feedback. |
| `superpowers:requesting-code-review` | When a complex change needs a second opinion. |

## Hard Gates

- Skill declaration before action: before invoking any Superpowers skill, announce `触发 skill: <skill-name>`.
- Git safety before code: run `git status` before implementation.
- Work in the current checkout by default for this desktop-pet project.
- Checkpoint before non-worktree `opsx:apply` when safe; never commit unrelated user changes without approval.
- Failing test before implementation code.
- Spec compliance review after each task.
- Spec sync when implementation and design diverge.
- Spec targeting before proposal.
- Parallelism safety for shared files and tests.
- Pre-apply dispatch recheck after artifact changes.
- Manual QA awareness for UI/UX changes.

## Hotfix Exception

All three conditions must be met to bypass Phase 0-1:

1. Scope: one file and <=15 changed lines.
2. Type: text, comment, config, or copy only; no logic changes.
3. Trigger: the user explicitly says `hotfix` or `trivial`.

Even when the exception applies:

- `superpowers:verification-before-completion` is still required.
- Tests or the best available checks must pass before declaring completion.
- If the fix grows beyond the bounds above, stop and re-enter the full flow.

## Language And Reasoning

- Reasoning language: English for logical precision with technical docs.
- Output language: Chinese, unless a technical term or code snippet requires English.
- Implicit translation: think in English, output in Chinese.
