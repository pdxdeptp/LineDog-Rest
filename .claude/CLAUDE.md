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

## Additional Hard Gate

- **Spec Targeting BEFORE proposal.** Every change must declare affected main spec ids and place delta specs in matching `specs/<spec-id>/` folders before implementation.



## Git Workflow for This Desktop-Pet Project

This project requires frequent manual QA in the running desktop app. Because manual verification usually happens from the current project directory, git worktrees are NOT required by default for this project.

Default workflow:
1. Work directly in the current project directory.
2. Before making changes, run `git status`.
3. If there are existing user changes, ask before touching overlapping files.
4. Prefer creating a checkpoint commit before large or risky changes.
5. Keep changes scoped to the requested feature or fix.
6. After implementation, run relevant automated checks where available.
7. The user will manually verify UI/UX behavior in the running desktop app.

Use a git worktree only when:
- The user explicitly asks for one.
- Multiple unrelated features must be developed in parallel.
- A risky experiment should be isolated from the current working directory.
- The current directory must remain on a stable main branch for comparison.

For this desktop-pet project, this project-level rule overrides the global “Git worktree BEFORE code” rule.
