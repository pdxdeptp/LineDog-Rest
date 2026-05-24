# ITEM-003 V1 / Current-State Observation

## Scope

- Item: ITEM-003 `study-plan-adjustment`
- Source: US-8, US-9, US-10, US-11, US-15, US-16, US-20, US-21, D20-D28
- Change: `introduce-study-plan-adjustment`
- Observation time: 2026-05-24T03:00:05Z

## Git / Safety

- Start status contained automation-owned ITEM-002 implementation files, Flow B state/progress files, and no detected unrelated user edits.
- Work stayed in the current checkout. No worktree was created or used.
- This round did not write implementation code.

## Existing Backend Behavior

- `assistant_backend/src/db/queries.py` has a generic `reschedule_task(db, task_id, new_date)` helper that updates one task date and increments `reschedule_count`.
- The helper does not perform v2 same-project cascade, does not reset auto-roll state, and does not record the affected task set required by D10/D11.
- `complete_task` now updates v2 completion/progress facts from ITEM-002 and can transition all-tasks-complete study projects into completed history.
- `get_study_calendar_load` already computes over-capacity days, but Project Overview does not yet expose expected-late state.
- There is no active-plan API for task insertion, task deletion, deadline editing, rollover, rest-day settings, or dialogue preview/apply.
- The existing v1 `conversational_agent` can produce proposals and apply task updates after confirmation, but it is LLM-shaped, uses broad tools, can update priority, and does not enforce the v2 mechanical cascade/red-state boundary.

## Existing Swift / UI Behavior

- `AssistantPanelView` exposes first-class Today, Project Overview, Calendar, Add Resource, Resource Progress, Adjust Plan, and Settings tabs.
- Today supports local display reordering through `moveVisibleTasks`, but that is Swift-local display order, not persisted date adjustment.
- `TaskRowView` has a visual drag handle, but active plan date movement is not implemented.
- Project Overview shows progress/deadline facts but does not yet surface expected-late red status.
- Calendar is intentionally read-only from ITEM-002 and has no drag, reschedule, add, or delete controls.
- `ChatView` is used for Adjust Plan. App observation showed the current Adjust Plan tab is effectively a blank chat/input area with no v2-specific preview/apply cards or structured adjustment controls.

## App Use / Computer Use Observation

- Current checkout app launched from `/Users/cpt/Library/Developer/Xcode/DerivedData/MalDaze-bpwxiacqyfwxjndsvopwqmqitret/Build/Products/Debug/MalDaze.app`.
- Computer Use attached to `MalDaze`, but because multiple same-bundle DerivedData apps exist it targeted the pet-stage window from another build path. That extra process was killed.
- The current checkout dashboard was observed through its CGWindow and accessibility controls.
- Screenshot: `app-use-screenshots/adjust-plan-current.png`.
- The Adjust Plan tab showed only the generic message input; no plan adjustment preview/apply surface was present.

## Summary

The current system has enough persisted study-plan and view facts to build ITEM-003, but adjustment behavior is still v1-shaped or absent. The gap is not a small UI polish pass; it requires a dedicated OpenSpec slice with backend adjustment primitives, red-state facts, Swift API/ViewModel state, and minimal UI controls.
