## Context

The current checkout now has v2 project intake, draft confirmation, Today, Project Overview, Calendar load, task completion, and completed history. Adjustment remains v1-shaped: the Adjust Plan tab is an empty generic chat box, backend chat uses an LLM planner that can propose task updates, and the only primitive task mutation is a non-cascading `reschedule_task` helper used by old agents.

This change introduces the third v2 slice, `study-plan-adjustment`, covering US-8 through US-11, US-15, US-16, US-20/21, and D20 through D28. The product center is still user-owned planning. The system only performs the user's literal action plus explicit mechanical rules; it does not optimize, repair, or suggest in default mode.

## Goals / Non-Goals

**Goals:**

- Roll incomplete active study tasks forward to the current day without cascading later project tasks.
- Allow user-initiated date moves to cascade by the same delta within the selected project only.
- Allow deadline edits without silently moving tasks.
- Compute and expose expected-late and over-capacity red states from persisted facts.
- Allow active-plan task insertion and deletion with D20-D23 semantics.
- Allow weekly and single-day rest-day settings, with D27 +1 day cascade for newly added rest days.
- Add a bounded dialogue adjustment preview/apply path for explicit user commands such as "push this project by one week".

**Non-Goals:**

- Smart mode, morning briefings, or multi-option assistant suggestions.
- Cross-project optimization or automatic repair of red states.
- Drag/drop polish beyond the minimal UI hooks needed to execute and verify deterministic date changes.
- Editing completed project history.
- Retiring old v1 learning specs or deleting v1 chat endpoints in this change.

## Decisions

### Decision 1: Adjustment state is a backend fact, not a Swift-only reorder

ITEM-002 currently supports local display ordering for Today, but v2 adjustment changes the actual plan. The backend will expose explicit adjustment endpoints and return refreshed study facts. Swift local order remains a display convenience only.

### Decision 2: Rollover is idempotent and tied to view refresh

US-8 says unfinished tasks appear the next day without user action. A local desktop app does not need a daemon for this slice; the backend can run an idempotent rollover before returning Today or adjustment facts. It moves incomplete active study tasks scheduled before today to today, increments an auto-roll counter by the number of days moved, and does not cascade same-project successors.

### Decision 3: User date changes reset rollover baseline

Rolling days measure missed-task drift, not user intent. When a user moves a task, a dialogue command shifts a project, or D27 rest-day cascade shifts tasks, affected tasks reset their auto-roll marker. Completion also clears the marker.

### Decision 4: Date moves cascade by project order

When the user changes one active unfinished task from date A to date B, the selected task and unfinished same-project tasks after it move by delta `B - A`. Project order is derived from unit order, task scheduled date, and task id where needed. Completed tasks and other projects are not moved.

### Decision 5: Red states are computed, not fixed

Expected-late means at least one active task in the project is scheduled after the project deadline. Over-capacity means a day's active study task target minutes exceed the configured daily capacity. These states are returned to views and can turn UI red, but this change does not modify the plan to hide them.

### Decision 6: Add/delete task is literal

Deleting an unfinished active task removes only that task and does not shift successors. Inserting a task requires title, target minutes, project, and scheduled date; it creates the task at that date and does not shift existing tasks. If all remaining unfinished tasks in a project disappear, the project completes and remains in completed history.

### Decision 7: Rest-day changes are explicit plan adjustments

Rest days are days with zero available learning capacity. Adding a new weekly weekday or one-off date performs D27's +1 day cascade for future unfinished active study tasks on and after each affected date. Removing a rest day does not cascade; it only allows future scheduling there.

### Decision 8: Dialogue adjustment is route A, not agent autonomy

US-16 uses natural language as a user input method. The first supported command family should be bounded and previewable, for example project-level push/delay by N days. The chat endpoint may use an LLM to parse user intent, but it must return a structured preview and must not write until the user presses Apply. Unsupported instructions return a clear no-op or request clarification.

## Data Model

Likely additions:

- `tasks.auto_roll_days INTEGER DEFAULT 0`
- `tasks.last_auto_rolled_at DATE`
- `tasks.user_adjusted_at TIMESTAMP`
- `study_rest_days` or `system_state` keys for weekly rest weekdays and one-off rest dates

Implementation may choose exact storage names during TDD, but must preserve these facts:

- per-task accumulated auto-roll days,
- whether a date is a rest day,
- whether an adjustment was user-initiated or system rollover,
- an event log for rollover, manual move, deadline edit, add, delete, rest-day cascade, and dialogue apply.

## API Shape

Candidate endpoints:

- `POST /api/study-plan-adjustment/rollover`
- `POST /api/study-plan-adjustment/tasks/{task_id}/move`
- `POST /api/study-plan-adjustment/projects/{project_id}/deadline`
- `POST /api/study-plan-adjustment/projects/{project_id}/tasks`
- `DELETE /api/study-plan-adjustment/tasks/{task_id}`
- `GET /api/study-plan-adjustment/rest-days`
- `PUT /api/study-plan-adjustment/rest-days`
- `POST /api/study-plan-adjustment/dialogue/preview`
- `POST /api/study-plan-adjustment/dialogue/apply`

Responses should include refreshed affected facts or enough identifiers for the ViewModel to refresh Today, Project Overview, and Calendar.

## Review / Readiness Notes

- The change is large but internally coherent because all requirements share one invariant: user action plus mechanical rule, no hidden repair.
- D26/D27 are included because automation scoped ITEM-003 to D20-D28, even though the item list originally omitted US-20. This avoids leaving rest-day cascade undefined.
- Smart-mode proposal generation remains out of scope and belongs to ITEM-004.
- `introduce-study-views` is complete but not archived yet. This change may extend view payloads in implementation while keeping the new spec id isolated.

## Rollback

The implementation should be additive: new adjustment routes, helper functions, schema migrations, and UI controls. Rollback can remove the new adjustment endpoints/UI wiring and leave ITEM-001/002 intake and factual views operational.
