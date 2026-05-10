# Project-Specific Claude Code Rules

These rules supplement the global CLAUDE.md for this project only.

## OpenSpec Spec Targeting Gate

Before creating any OpenSpec change artifacts, the agent MUST resolve which main specs the change modifies.

1. Run `openspec list --specs`.
2. Identify existing spec ids affected by the change.
3. Record them in `proposal.md` under an `Affected Specs` section.
4. Put delta specs under `openspec/changes/<change-name>/specs/<spec-id>/spec.md`, where `<spec-id>` exactly matches the target main spec folder.
5. Only create a new `<spec-id>` when no existing main spec describes the capability.

Archive sync is path-driven: `changes/<change>/specs/<spec-id>/spec.md` merges back to `openspec/specs/<spec-id>/spec.md`. Do not rely on change-name semantics or natural-language guessing for archive targets.

## Soft Pre-Apply Guidance after `opsx:propose`

After `opsx:propose` creates or updates a change, do not immediately present `opsx:apply` as the only next step. Summarize that the proposal/design/specs/tasks are ready and offer a short choice:

- **Lightweight path:** run `opsx:apply-readiness <change>` before implementation.
- **Full pre-apply path:** run `opsx:product-deepen <change>` → `opsx:scope-decision <change>` → `opsx:apply-readiness <change>`.
- **Pause:** leave the change ready for later review or manual edits.
- **Direct apply:** proceed only if the user explicitly wants to skip pre-apply review.

Do not automatically run the full three-skill sequence by default. Recommend the full path for medium/large, user-visible, async, multi-agent, data-writing, or cross-module changes; keep the lightweight path acceptable for small, well-bounded changes.

## Pre-Apply Dispatch Recheck

If `opsx:product-deepen`, `opsx:scope-decision`, or `opsx:apply-readiness` changes `tasks.md`, `design.md`, or spec deltas before implementation, the agent MUST re-check subagent dispatch boundaries before starting `opsx:apply`.

- Re-read the final `tasks.md` and identify shared write targets, especially shared test files, app entry points, route registries, project files, and common clients/view models.
- Do NOT dispatch parallel subagents for tasks that modify the same file or the same test surface.
- If implementation tasks share test files or setup files, run those tasks sequentially or assign the shared file to exactly one worker.
- When in doubt, choose sequential execution over parallel execution.

## Additional Hard Gate

- **Spec Targeting BEFORE proposal.** Every change must declare affected main spec ids and place delta specs in matching `specs/<spec-id>/` folders before implementation.
- **Checkpoint BEFORE non-worktree apply.** Before `opsx:apply`, if no git worktree is being used, create a checkpoint commit for the current code state.
- **Pre-Apply Dispatch Recheck.** If pre-apply review changes artifacts, re-read final `tasks.md` and re-plan subagent boundaries before implementation; shared test/setup files must be sequential or owned by exactly one worker.
- **Manual QA Awareness.** For UI/UX changes, account for the user's need to restart or interact with the local desktop app and ensure the modified code is in the directory the user is actually running.

## Project Finalization Override

When all tasks are complete in this desktop-pet project:

1. Run `superpowers:verification-before-completion` to verify relevant tests/checks pass, review has passed, and manual QA requirements have been communicated or completed.
2. Present the current state and next-step options, such as committing the completed changes, creating a GitHub PR, keeping the changes uncommitted for further manual testing, or discarding the changes and restoring the previous state.
3. Run `superpowers:finishing-a-development-branch` only if a git worktree was used, then clean up the worktree after the user chooses how to proceed.



## Git Workflow for This Desktop-Pet Project

This project requires frequent manual QA in the running desktop app. Because manual verification usually happens from the current project directory, git worktrees are NOT required by default for this project.

Default workflow:
1. Work directly in the current project directory.
2. Before making changes, run `git status`.
3. If there are existing user changes, ask before touching overlapping files.
4. Prefer creating a checkpoint commit before large or risky changes.
5. Before `opsx:apply`, if no git worktree is being used, create a checkpoint commit for the current code state.
6. Keep changes scoped to the requested feature or fix.
7. After implementation, run relevant automated checks where available.
8. The user will manually verify UI/UX behavior in the running desktop app.

Use a git worktree only when:
- The user explicitly asks for one.
- Multiple unrelated features must be developed in parallel.
- A risky experiment should be isolated from the current working directory.
- The current directory must remain on a stable main branch for comparison.

For this desktop-pet project, this project-level rule overrides the global “Git worktree BEFORE code” rule.
