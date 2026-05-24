# ITEM-003 Gap Analysis

## Target Behavior

`study-plan-adjustment` must let the user change an active plan while preserving the v2 invariant:

> The system only executes the user's literal action plus explicit mechanical rules; it does not silently optimize, repair, or propose in default mode.

## Gaps

### US-8 / D9: Unfinished Task Rollover

- Current: tasks remain on their scheduled date unless a helper explicitly reschedules them.
- Needed: idempotent rollover of incomplete active study tasks scheduled before today into today, no cascade, auto-roll count, and badge facts.

### US-9 / D10 / D11: Manual Date Move Cascade

- Current: `reschedule_task` moves one task only.
- Needed: selected task moves by user delta, unfinished later same-project tasks shift by the same delta, completed tasks and other projects stay fixed, event evidence records the affected set.

### US-10: Deadline Editing

- Current: project deadline is set during intake and displayed later, but there is no active-plan endpoint for editing it.
- Needed: deadline edit updates the resource only, does not move tasks, and recalculates expected-late state.

### US-11: Red State Facts

- Current: Calendar can mark over-capacity days; Project Overview lacks expected-late state and enriched red status.
- Needed: red states are derived facts after every adjustment and shown without automatic repair.

### US-15 / D20-D23: Add/Delete Tasks

- Current: no active-plan add/delete task API.
- Needed: insert task with title/minutes/date and no cascade; delete one unfinished task with no cascade; completed history stays read-only; deleting the last unfinished task transitions the project to completed history.

### US-20 / D26-D27: Rest Days

- Current: scheduler accepts a rest-weekdays concept internally, but active settings and D27 cascade are not exposed.
- Needed: weekly and one-off rest days, add-rest-day +1 day cascade for future unfinished tasks, remove-rest-day no cascade.

### US-21 / D28: Rolled Badge

- Current: `reschedule_count` exists but conflates old v1 rescheduling with user/manual changes.
- Needed: separate auto-roll count and badge threshold of 3 days, reset on user-owned moves/cascades/dialogue apply.

### US-16 / D25: Dialogue Adjustment

- Current: v1 chat is generic, LLM-driven, and can apply broad task updates after confirmation.
- Needed: bounded route-A adjustment preview/apply, no mutation before Apply, exact previewed changes on apply, safe no-op for unsupported instructions.

## Scope Decision

Keep all D20-D28 behavior in one OpenSpec change because it shares one persisted adjustment model and one refresh contract. Defer smart-mode proposal generation to ITEM-004; this change may produce red states but must not generate smart suggestions.
