# ITEM-002 Gap Analysis: Study Views

## Target

Implement the v2 factual study views slice:

- Today view for all active study tasks scheduled today.
- Task completion updates project progress.
- Project overview for active projects plus completed/archive history.
- Calendar view for future task distribution and load.
- Automatic archival/completion of projects when no unfinished tasks remain.

## Current Gaps

### Gap 1: Today View Source Is V1 Agent-Shaped

- Current UI can display today's tasks, but the backend source is `/api/today-briefing`.
- `/api/today-briefing` may call `run_morning_agent()` and returns highlights, which is v1 morning-agent behavior.
- V2 needs deterministic facts from the calendar/task tables, not LLM/cached briefing semantics.

### Gap 2: Completion Does Not Return A V2 View Snapshot

- `complete_task` mutates the task and resource counters, but the view layer refreshes via the existing dashboard flow.
- ITEM-002 needs task completion to reliably update today view and project progress without relying on morning briefing side effects.

### Gap 3: Project Overview Is Active-Only Resource Progress

- The existing `资料进度` tab is close to a project overview for active projects.
- It does not include completed/archive history, which US-14 requires for reviewable completed records.
- It presents generic resource management actions, not a v2 project overview contract.

### Gap 4: Calendar View Is Missing

- The database can aggregate future scheduled task counts and minutes.
- The UI has no calendar view that shows the next several weeks, daily total minutes, task count, load versus capacity, or overloaded days.

### Gap 5: Auto Archive Semantics Need A V2 Contract

- Existing `complete_task` marks a resource `completed` when completed units reaches total units.
- The v2 design says all tasks done means the project auto-archives while preserving history.
- The implementation can represent this as a completed, non-active project that leaves daily/project active views and appears in history, but the spec must make that explicit.

## Proposed Slice Boundary

### In Scope

- New capability/spec id: `study-views`.
- Deterministic backend view APIs for:
  - today task list,
  - project overview,
  - calendar load window.
- Task completion update path used by the v2 views.
- Swift models/client/view-model/UI for Today, Project Overview, and Calendar.
- Completed project history in overview.

### Out Of Scope

- Rolling unfinished tasks (US-8 / US-21).
- Drag/drop date changes, deadline editing, add/delete tasks, and conversation adjustment (ITEM-003).
- Smart mode, morning briefing, and candidate adjustment suggestions (ITEM-004).
- Retiring old v1 learning specs.

## Readiness Notes

- The slice depends on ITEM-001 because it needs confirmed active study projects and target-minute tasks.
- It can be implemented without worktrees.
- It will likely touch the same learning assistant Swift files as ITEM-001. Those changes are automation-owned, so the next `opsx:apply` can checkpoint the current checkout before implementation.
