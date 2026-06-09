# AGENTS.md

This is the compact project contract. Full workflow detail lives in `docs/agent-workflow.md`.

## Always
- Cross-repo Hermes coupling (canonical, maintain here only): `docs/integrations/hermes.md`. Hermes side is pointer-only: `~/.hermes/docs/integrations/maldaze.md`.
- **Hermes read-only UI (MalDaze)**: JSON/contract from Hermes is the only source of truth. Never add client-side suppression, optimistic hiding, shadow lists, or local filters to mask backend recalculation—fix Hermes/contract or document expected behavior. See `docs/agent-workflow.md` § Hermes read-only UI.
- **SSOT, no shadow copies**: Prefer one authoritative store per fact; derive or read from it instead of caching the same field in profile/defaults/a second JSON. Avoid intermediate layers. See `docs/agent-workflow.md` § SSOT and intermediate layers.
- Output in Chinese; reason in English unless code or technical terms require English.
- Protect user work: never reset, revert, overwrite, merge, or rebase user changes without explicit permission.
- Before invoking any Superpowers skill, announce: `触发 skill: <skill-name>`.
- Keep this file concise; move expanded rationale and examples to `docs/agent-workflow.md`.

## Design Before Code
- New feature or exploration: use `opsx:explore`; do not implement.
- Clear direction: use `opsx:propose` to create `proposal.md`, `design.md`, specs, and `tasks.md`.
- Before proposal: run `openspec list --specs`, identify affected spec ids, record `Affected Specs`, and place deltas under matching `specs/<spec-id>/spec.md`.
- Gate: `openspec/changes/<change>/tasks.md` must exist before implementation.
- After proposal, offer readiness review, full pre-apply review, pause, or direct apply; direct apply only when explicitly requested.

## Git Safety
- Before implementation, run `git status`.
- Work in the current checkout by default because this desktop app needs local manual QA.
- If existing changes are present, avoid overlapping files unless the user approves.
- Before non-worktree `opsx:apply`, create a checkpoint commit when safe; never include unrelated user changes without approval.
- Use a worktree only when requested, for unrelated parallel features, risky experiments, stable-main comparison, or work that does not need local QA.

## Implementation
- Entry point: `opsx:apply`.
- Fixed chain: `opsx:apply` -> `superpowers:subagent-driven-development` -> per-task `superpowers:test-driven-development`.
- Main agent orchestrates, reviews, and integrates; subagents write implementation code.
- Re-read final `tasks.md` before dispatch; do not parallelize overlapping files, tests, setup, app entry points, clients, or view models.
- TDD law: RED failing test -> GREEN minimal code -> REFACTOR; implementation code before a failing test is deleted.
- After each task, run spec compliance and code quality review; critical issues block progress.
- If implementation reveals spec drift, update the OpenSpec delta before continuing.

## Verification And Finalization
- Before saying done, use `superpowers:verification-before-completion` and run fresh relevant checks.
- For UI/UX changes, explain how to manually verify in the running desktop app.
- Present next steps: commit, PR, keep uncommitted, or discard only by explicit request.
- If a worktree was used, run `superpowers:finishing-a-development-branch` and clean it up after user choice.

## Hotfix Exception
- Bypass Phase 0-1 only when the user says `hotfix` or `trivial`, the change is one file, <=15 lines, and copy/comment/config only.
- Even then, verify and run tests/checks; if scope grows, re-enter the full flow.

## On-Demand Skills
- Use `superpowers:brainstorming` for pure divergent ideation before OpenSpec.
- Use `superpowers:systematic-debugging` for non-obvious bugs.
- Use `superpowers:receiving-code-review` for human or agent review feedback.
- Use `superpowers:requesting-code-review` for complex second opinions.
