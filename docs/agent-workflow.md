# Agent Workflow Reference

This document preserves expanded workflow rationale and examples. Keep `AGENTS.md` as the short entry contract and workflow router, ideally under 60 lines. Mode-specific operating rules live in `docs/agent-modes/` and should be read on demand, not all at once.

## Workflow Mode Router

The project does not treat the heaviest OpenSpec pipeline as the default for every task. Agents should choose the lightest mode that protects user work and produces verifiable evidence.

| Mode | Read | Use When |
| --- | --- | --- |
| Fast Path | `docs/agent-modes/fast-path.md` | Small, clear fixes; docs/config/copy; known-root-cause bugs |
| Standard Path | `docs/agent-modes/standard-path.md` | Moderate user-visible changes or several-file edits |
| Full Delivery | `docs/agent-modes/full-delivery.md` | User asks for end-to-end completion, full QA, or vibe coding |
| High Risk | `docs/agent-modes/high-risk.md` | Hermes contracts, SSOT/persistence, data loss, window lifecycle, unclear root cause, architecture |

Do not read every mode file by default. `AGENTS.md` routes to one mode; that mode may escalate if risk appears.

## OpenSpec / Full-Path Reference

The strict pipeline still exists for modes that call for it, especially Standard Path product changes, Full Delivery, and High Risk work:

`Design (OpenSpec) -> Plan Refinement -> Git Safety Check -> Implementation (TDD/review as appropriate) -> Finalization`

## Phase 0: Design Refinement

When a selected mode requires OpenSpec, or when a new feature/product behavior needs exploration:

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
5. Before non-worktree `opsx:apply`, create a checkpoint commit only when safe and useful; skip it when unrelated dirty changes would make the checkpoint misleading.
6. Never include unrelated user changes in a checkpoint commit without approval.

Default workflow:

1. Work in the current project directory.
2. Keep changes scoped to the requested feature, fix, or OpenSpec task.
3. Run relevant automated checks.
4. Ask the user to manually verify UI/UX behavior in the running desktop app when visual or interaction behavior changes, unless Full Delivery calls for agent-side UI verification.
5. Commit or prepare changes only after implementation and verification, unless the user requests an earlier checkpoint.

### When To Use A Worktree

Use a git worktree only when:

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

For modes that require delegated implementation, the entry point is `opsx:apply`. The OpenSpec task list owns execution scope, dispatch follows the rules below, and every behavior task follows the TDD discipline in this document.

Fast Path and many documentation-only tasks do not need subagents. If the active environment does not permit spawning subagents unless the user explicitly asks for them, follow the higher-priority environment rule and document the deviation.

### Dispatch Rules

1. Analyze for parallelization.
   - Independent components can run in parallel.
   - Shared files or strict dependencies run sequentially.
2. Give each subagent only the relevant task, spec excerpt, and target files.
3. The main agent orchestrates, reviews, and integrates; subagents write implementation code.

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

In Full Delivery and High Risk modes, each task output receives:

1. Spec compliance review.
   - Does the code fulfill `openspec/changes/<change>/specs/` requirements?
   - Are all scenarios covered?
2. Code quality review.
   - Check security, performance, duplication, error handling, and maintainability.
   - Critical issues block progress.

If implementation reveals a design flaw, update the OpenSpec delta before continuing.

## Phase 3: Finalization

When all tasks are complete:

1. Run fresh relevant tests and checks.
2. Confirm review passed or list remaining review gaps.
3. Communicate manual QA needs or results for UI/UX changes.
4. Present next-step options:
   - Commit completed changes.
   - Create a GitHub PR for review.
   - Keep changes uncommitted for further manual testing.
   - Discard changes only by explicit user request.
5. If a worktree was used, clean it up only after the user chooses the finalization path.

## Hard Gates

- Git safety before code: run `git status` before implementation.
- Work in the current checkout by default for this desktop-pet project.
- Use the selected mode file; do not default to the heaviest path.
- Checkpoint before non-worktree `opsx:apply` only when safe and useful; never commit unrelated user changes without approval.
- Failing test before implementation code when a meaningful behavior test can be written.
- Spec compliance review after each task in Full Delivery and High Risk modes.
- Spec sync when implementation and design diverge in OpenSpec-backed work.
- Spec targeting before OpenSpec proposal.
- Parallelism safety for shared files and tests.
- Pre-apply dispatch recheck after artifact changes when using OpenSpec apply.
- Manual QA awareness for UI/UX changes; Computer Use is opt-in or mode-triggered.

## Fast-Path Exception

Fast Path replaces the old narrow hotfix-only exception. Use it for small, clear fixes or docs/config/copy changes that do not alter high-risk contracts.

Fast Path still requires:

- Git status before editing.
- Focused verification before declaring completion.
- Clear manual QA steps for UI/UX behavior.
- Escalation when root cause, scope, or risk grows.

## SSOT And Intermediate Layers

Project preference (MalDaze + Hermes integrations): **one fact, one authoritative store**. Do not add profile fields, UserDefaults mirrors, or parallel JSON blobs that duplicate data already living in the canonical file or log.

### Do

- Name the SSOT in design/spec (e.g. `training_log.json` for strength sessions, `daily_log.json` for today’s day type, `projects.json` for learning tasks).
- **Derive** display or “next value” by reading the SSOT (latest record, today’s row, contract `panel`).
- Use **derived views** only when clearly labeled (e.g. `daily_log.panel` for MalDaze UI)—never a second writable copy of the same fact.
- When backfilling history, patch the SSOT (and optional archive), not a convenience cache elsewhere.

### Do not

- Add `profile.last_*` (or similar) when the event log already has the data—same class of mistake as removed `profile.last_training_date`.
- Maintain the same field in profile + daily_log + training_log + history unless each has a **distinct** role (today vs history vs derived UI).
- Introduce a client-side or agent-side “shadow list” to paper over SSOT recalculation (see § Hermes Read-Only UI).

### Canonical example (nutrition · workout split)

**Wrong**: `profile.last_workout_split` cached “last chest/back day” while `training_log` already records each `is_training=true` session with `workout_split`—three places to seed and drift.

**Right**: alternation reads the latest strength record from `training_log` (exclude today when assigning); `daily_log.workout_split` holds **today only**; `panel.workoutLabel` is derived for MalDaze. Same pattern as `cmd_auto_day` reading last training **date** only from `training_log`, not profile.

### When proposing a new field

Ask: *Where is the SSOT?* If the answer is “profile for speed” but a log/contract already exists, **extend the log/contract** instead.

## Hermes Read-Only UI (MalDaze)

MalDaze panels that consume Hermes file contracts (`daily_log.panel`, `sleep_schedule.json`, `schedule.py` via CLI, etc.) are **display + invoke CLI only**. Hermes owns computation, persistence, and recalculation.

### Do

- Read the contract; render what is on disk after FSEvents/debounce/poll.
- On user action that mutates Hermes data, call the documented subprocess/CLI (`recommend.py log`, `schedule.py complete`, …) and **reload** from the contract.
- If displayed state looks wrong after reload, fix **Hermes** (`recommend.py`, `_attach_panel`, specs) or clarify product/spec—not MalDaze overlays.

### Do not (anti-patterns)

- **Suppression / shadow lists**: hide rows the contract still contains (e.g. `suppressedSuggestionKeys`, “filter out what user just logged”).
- **Optimistic UI that diverges from contract**: show a trimmed menu before reload while the file still has the old `panel`.
- **Client-side re-suggestion**: re-run nutrition/plan logic in Swift to “fix” stale Hermes output.

### Canonical failure example (never repeat)

`add-nutrition-today-panel`: after `log`, suggestions looked unchanged because Hermes often returns the same or empty menu post-recalc. The wrong fix was MalDaze-side “session suppression” of logged items. The right model: `log` → `_update_daily_log` → `_attach_panel` → MalDaze `loadToday()` shows the new `panel` as-is. If recalc behavior is wrong, change Hermes or the OpenSpec—not a second truth in the app.

## Language And Reasoning

- Reasoning language: English for logical precision with technical docs.
- Output language: Chinese, unless a technical term or code snippet requires English.
- Implicit translation: think in English, output in Chinese.
