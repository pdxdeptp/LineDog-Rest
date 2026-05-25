## Scope

This change schedules validated task candidates. It does not generate them.

Included:

- date-window construction;
- capacity calculation;
- buffer reservation;
- load-shape placement;
- continuation-session splitting;
- risk report;
- infeasibility option mapping;
- deterministic option effects;
- scope/depth reduction audit facts;
- hard deadline guardrails;
- end-to-end schedule dry runs.

Excluded:

- intake routing;
- LLM phase/task generation;
- physical draft persistence internals;
- UI controls;
- automatic movement of existing active tasks.

## Scheduler Inputs

- ordered validated task candidates;
- normalized estimates and confidence;
- allowed start date;
- deadline;
- deadline type: hard, soft, or assumed;
- daily capacity;
- existing active load by date;
- rest days and one-off unavailable days;
- buffer policy;
- load shape: balanced, front-loaded, or light-start;
- essential/optional/stretch classification;
- approved split points or multi-session boundaries.

If daily capacity is missing, use the learning preference default of 60 minutes.

## Capacity Terms

- `rawCapacity(date)`: user's available minutes for that date.
- `existingLoad(date)`: minutes already occupied by confirmed active plans.
- `usableCapacity(date)`: `max(0, rawCapacity - existingLoad)`.
- `planningBudget(date)`: usable capacity available to the new draft. By default, new plans use at most 80% of usable capacity unless the user chooses crunch/overload.

Rest days and unavailable days have zero normal placement capacity. They may only receive fallback/reading work when the user explicitly chooses that date.

## Default Algorithm

1. Build date window from start date through deadline.
2. Remove rest days and one-off unavailable days from normal placement.
3. Compute usable capacity and planning budget for each remaining date.
4. Reserve buffer near deadline:
   - 1 usable day when the plan has at least 3 usable days;
   - about 20% of usable days, clamped to 1-5 days, for longer plans.
5. Split tasks above the normal planning budget only at approved split points or multi-session boundaries.
6. Place essential work in dependency order.
7. Place optional/stretch work only after essential work fits.
8. Preserve dependency order; mark expected-late instead of reordering to hide risk.
9. Return scheduled tasks and risk report even when infeasible.

The scheduler must not lower target depth, extend deadline, move existing active tasks, invent missing tasks, or create Today actions before activation.

## Continuation Sessions

If a task estimate exceeds the normal planning budget for available days:

- split only at `splitPoints` or explicit multi-session boundaries;
- keep parent task id and sequence number;
- include session estimate and visible sub-output or continuation note;
- if no meaningful split exists, return expected-late, overload, or capacity-gap facts.

## Risk Report

The scheduler returns:

- `fitsAsWritten`;
- capacity gap minutes;
- overloaded dates;
- expected-late tasks;
- buffer days reserved;
- buffer erosion;
- estimate confidence summary;
- existing-load conflicts;
- canonical infeasibility option ids.

Infeasibility is a review state, not an exception.

## Infeasibility Option Mapping

| Fact | Allowed choices |
| --- | --- |
| `capacity_gap` | `reduce_scope`, `lower_depth`, `extend_deadline`, `increase_capacity`, `accept_crunch` |
| `buffer_erosion` | `accept_buffer_risk`, `reduce_scope`, `extend_deadline`, `increase_capacity` |
| `overloaded_dates` | `rebalance`, `increase_capacity`, `reduce_scope`, `accept_overload` |
| `expected_late` | `extend_deadline`, `reduce_scope`, `lower_depth`, `accept_late_finish` |
| `low_calibration` | `answer_one_question`, `edit_estimates`, `accept_rough_draft`, `store_for_later` |

For hard deadlines, `accept_late_finish` is not available.

## Option Effects

- `extend_deadline`: update deadline and rerun scheduler.
- `increase_capacity`: update capacity and rerun scheduler.
- `accept_crunch`: raise/remove budget cap for selected dates and rerun scheduler.
- `accept_buffer_risk`: keep buffer erosion visible and allow activation only after explicit confirmation.
- `rebalance`: rerun scheduler with same scope/depth/deadline/capacity and different distribution.
- `accept_overload`: keep overload visible and allow activation only after explicit confirmation.
- `edit_estimates`: keep task structure and rerun scheduler after estimate edits.
- `accept_rough_draft`: allow activation only if there are no blocking validation errors and assumptions stay visible.
- `store_for_later`: exit active planning and create no active tasks.
- `accept_late_finish`: allowed only for soft/assumed deadlines.

`reduce_scope` and `lower_depth` may require cooperation with the compiler, but the scheduler owns the before/after fit math and option availability.

## Scope And Depth Reductions

`reduce_scope` preserves target output and target depth. It removes or unschedules work in this order:

1. stretch tasks;
2. optional polish or extra review tasks;
3. optional source sections not required by target output;
4. secondary modifiers;
5. optional practice volume above the minimum cadence/checkpoint needed for the target.

It must not remove essential evidence. If no optional/stretch work remains and the plan still does not fit, `reduce_scope` is not available as a standalone fix.

`lower_depth` changes completion obligations and regenerates affected phases/tasks before rescheduling. The review must show minutes removed, tasks changed, evidence lost, target-output impact, and new fit/risk state.

## Dry Runs

Scheduler tests should include:

- feasible resume/project packaging: 285 essential minutes, 300 available execution minutes before buffer, 1 buffer day, `draft_review`;
- infeasible easyagent source-understanding rebuild: 525 essential minutes, 300 execution minutes, 225-minute capacity gap, hard deadline, no `accept_late_finish`, and `reduce_scope` unavailable as a standalone fix.
