## Context

ITEM-001 created the v2 study-plan foundation: URL intake, guided clarification, draft scheduling, review edits, and explicit confirmation into active resources/tasks. The current daily and progress surfaces still come mostly from v1: `/api/today-briefing` can run the morning agent, and `/api/resources` returns active resource cards. That is useful plumbing but not the v2 source of truth.

ITEM-002 introduces deterministic study views. These views should read confirmed project/task facts from SQLite, expose them through dedicated APIs, and present them in Swift without asking an LLM for summaries or suggestions.

## Goals / Non-Goals

**Goals:**

- Make Today the default v2 daily view for active study tasks scheduled today.
- Make task completion update task state, unit state, project progress, and active/completed project visibility.
- Add a project overview that includes active projects and completed history.
- Add a calendar load view for the upcoming weeks.
- Keep all view data factual and user-owned; no proactive plan mutation.

**Non-Goals:**

- Rolling unfinished tasks into tomorrow.
- Dragging tasks between dates, deadline editing, add/delete task behavior, or conversation adjustment.
- Smart mode morning suggestions.
- Retiring v1 learning specs or removing old endpoints.
- Redesigning the whole dashboard shell beyond what the three factual views require.

## Decisions

### Decision 1: Add dedicated v2 view endpoints

Use new study-view endpoints instead of extending `/api/today-briefing` because `/api/today-briefing` is v1 morning-agent shaped and may generate/cached assistant text. ITEM-002 needs deterministic facts:

- today's active study tasks,
- active and completed project progress,
- daily load buckets for a date window.

Alternative considered: reuse `/api/today-briefing` plus `/api/resources`. Rejected because it preserves the v1 agent/cached summary boundary and makes Calendar view awkward.

### Decision 2: Treat completed projects as archived from active views

US-14 says projects auto-archive when all tasks are checked off. The backend can represent this as a completed non-active project status that disappears from active Today/Project cards and appears in completed history. This preserves records without conflating user-initiated "move out of plan" with natural completion.

Alternative considered: reuse manual `archived` status. Rejected because existing manual archive means "remove from current plan", while all-tasks-done is a successful completion event.

### Decision 3: Calendar load is factual, not corrective

Calendar view should aggregate task count and minutes per day, compare minutes with the configured daily capacity, and mark overloaded days. It must not move tasks or generate suggestions. Adjustment and smart-mode recommendations belong to later slices.

### Decision 4: Swift state should separate v2 view facts from v1 briefing facts

The ViewModel can keep existing fields during transition, but ITEM-002 should add explicit study-view state models so the UI does not depend on parsing `TodayBriefing.highlights` or resource cards as the v2 contract.

## Risks / Trade-offs

- Risk: This overlaps the existing home and resource progress tabs. -> Keep the new capability factual and use tests to ensure the v2 views do not rely on morning-agent summaries.
- Risk: Calendar view scope expands into drag/drop adjustment. -> Calendar is read-only in this slice; date mutation is ITEM-003.
- Risk: Completed project history increases payload size. -> Return compact project summaries, not every historical task body by default.
- Risk: Existing ITEM-001 dirty checkout increases implementation risk. -> Before `opsx:apply`, create a checkpoint commit if no unrelated user changes are present.

## Migration Plan

1. Add backend query helpers and router endpoints alongside existing v1 endpoints.
2. Add Swift API models and view-model state for the new v2 facts.
3. Route the learning assistant middle column to expose Today, Project Overview, and Calendar views.
4. Keep old endpoints alive until the planned v1 spec retirement step.

Rollback strategy: because this slice is additive, rollback can remove the new study-view endpoints/UI wiring while leaving ITEM-001 study-plan activation intact.

## Open Questions

None for this slice. Navigation placement may follow the existing app shell during implementation as long as Today, Project Overview, and Calendar are all first-class reachable views.
