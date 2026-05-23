# Learning Assistant v2 Flow B Progress

## Current Status

- Phase: OpenSpec proposal
- Current item: ITEM-001 `study-plan-foundation`
- Current change: `introduce-study-plan-foundation`
- Current spec: `study-plan`
- Checkout strategy: current checkout only; worktrees are forbidden by automation instruction.

## Round 01 · 2026-05-23T14:50:55Z

### Git / Safety

- Start status contained only automation-owned Flow A files and the updated `learning-assistant-v2.md` from the previous heartbeat.
- No user-created overlapping changes were detected in this heartbeat.
- No implementation code was written.

### Flow A Gate

- `openspec/learning-assistant-v2-flow-a/final-readiness-report.md` says `Flow B readiness: PASS`.
- Controller state is `phase=flow-b`.

### V1 Observation Summary

- Swift UI currently has `AssistantPanelView`, `LearningAssistantViewModel`, `AssistantAPIClient`, and supporting learning views.
- The current add-resource flow calls `/api/ingest/start`, listens to SSE, displays an ingestion draft, supports A/B schedule options, and confirms with `/api/ingest/confirm`.
- The backend uses FastAPI + LangGraph ingestion agent. It has URL handlers, batch duration estimation, A/B scheduling, interrupt-based confirmation, and SQLite tables for resources, units, tasks, events, and system_state.
- This is a useful baseline but still v1-shaped: it is resource ingestion plus autonomous agents, not a v2 study-plan calendar model with guided clarification, review-state plan drafts, deterministic D24 scheduling, and user-owned confirmation semantics.
- App Use observation found multiple `com.maldaze.MalDaze` bundle instances. The current checkout app path `/Users/cpt/Public/MalDaze/DerivedData/Build/Products/Debug/MalDaze.app` can be targeted, but its visible window was blank/menu-bar-like during this heartbeat. A fuller UI verification should happen after implementation when the app has a known launch path.

### OpenSpec

- Created change scaffold: `openspec/changes/introduce-study-plan-foundation`.
- New capability: `study-plan`.
- Affected existing specs for context only: `learning-data-layer`, `material-ingestion`, `assistant-panel-ui`, `conversational-planner`, `daily-morning-agent`, `progress-feedback`, `weekly-review-agent`.
- Old v1 specs are not modified in this change; retirement should remain a later dedicated change after v2 coverage exists.
- Created proposal/design/spec/tasks for `introduce-study-plan-foundation`.
- Ran `openspec validate introduce-study-plan-foundation --strict`: PASS.
- `openspec status --change introduce-study-plan-foundation --json` reports all required artifacts done and `isComplete=true`.

### Next Step

Before implementation, create a checkpoint commit in the current checkout, then enter `opsx:apply` with Superpowers subagent/TDD discipline.
