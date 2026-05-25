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

The scheduler accepts only compiler `draft_review` packages. Compiler `needs_input`
and `compile_failed` packages pass through to draft persistence/UI recovery and are
not scheduled by this change.

## Scheduler Output Contract

The scheduler returns a `ScheduledDraftReview` package. It is a pure review
payload; activation and persistence writes remain downstream.

Top-level fields:

- `schema_version`;
- `draft_id` and source `compiler_package_version`;
- `status`: `draft_review`, `infeasible_review`, or `needs_input`;
- `scheduled_days`: dated review rows with planned work, fallback mode, and daily load;
- `unscheduled_tasks`: optional/stretch or unsplittable work not placed;
- `risk_report`;
- `infeasibility_options`;
- `assumptions`;
- `scheduler_trace`.

`scheduled_days[]` contains:

- `date`;
- `raw_capacity_min`;
- `existing_load_min`;
- `usable_capacity_min`;
- `planning_budget_min`;
- `planned_minutes`;
- `load_state`: `within_budget`, `uses_buffer`, `over_budget`, or `over_capacity`;
- `items[]`, each with `task_id`, `phase_id`, `session_id`, `parent_task_id` when split, `sequence_index`, `scheduled_minutes`, `classification`, `completion_criteria`, `source_refs`, `normal_mode`, and optional `fallback_mode`.

The scheduler must not write active tasks, create Today actions, or mutate the
compiler package. It returns enough deterministic facts for draft persistence and
the Add / Initiate UI to store, review, retry, or activate later.

`draft_review` means all essential scheduled work finishes inside the deadline
without unaccepted overload and without unaccepted buffer erosion. Optional or
stretch work may remain unscheduled if the risk report makes that explicit.

`infeasible_review` means at least one essential task is late, unscheduled,
over-capacity, or requires unaccepted buffer/crunch/overload to finish.

`needs_input` means scheduling cannot run because a scheduler-required anchor is
missing or invalid and should not be guessed. It includes at most one focused
question plus visible defaultable assumptions and does not require `scheduled_days`.

## Scheduler Input Preflight

The scheduler preflight validates anchors before placement.

Required anchors:

- at least one validated task candidate in a compiler `draft_review` package;
- deadline;
- deadline type, defaulting to `assumed` when deadline is present but type is missing;
- start date, defaulting to today when missing.

Defaultable anchors:

- daily capacity defaults to 60 minutes;
- existing active load defaults to empty load with a visible assumption;
- rest weekdays and unavailable dates default to empty lists;
- buffer policy defaults to standard reservation.

If deadline is missing, date parsing fails, or no schedulable task candidate is
available, the scheduler returns `needs_input` rather than inventing a deadline
or creating an impossible plan.

## Date And Capacity Rules

All date calculations use the user's current local calendar day. The date window
is inclusive from `start_date` through `deadline`.

If `start_date` is missing, use today. If `deadline` is before `start_date`,
return `infeasible_review` with a hard date-window risk and do not place work
after the deadline.

Rest days and unavailable dates stay inside the date window with zero normal
capacity so review can explain why work was not placed there. They are not
normal placement days. Fallback/reading work can appear on those dates only when
the user explicitly chooses that date or a later option effect permits it.

Existing active load is read as per-date confirmed minutes. The scheduler may
show conflicts but must not move or edit those active tasks.

## Capacity Terms

- `rawCapacity(date)`: user's available minutes for that date.
- `existingLoad(date)`: minutes already occupied by confirmed active plans.
- `usableCapacity(date)`: `max(0, rawCapacity - existingLoad)`.
- `planningBudget(date)`: usable capacity available to the new draft. By default, new plans use at most 80% of usable capacity unless the user chooses crunch/overload.
- `reservedBuffer(date)`: capacity intentionally kept empty before the deadline.
- `executionBudget(date)`: planning budget available before unaccepted buffer or overload is consumed.

Rest days and unavailable days have zero normal placement capacity. They may only receive fallback/reading work when the user explicitly chooses that date.

## Default Algorithm

1. Build date window from start date through deadline.
2. Remove rest days and one-off unavailable days from normal placement.
3. Compute usable capacity and planning budget for each remaining date.
4. Reserve buffer near deadline:
   - 1 usable day when the plan has at least 3 usable days;
   - `ceil(usable_days * 0.2)` usable days, clamped to 1-5 days, for longer plans.
5. Split tasks above the normal planning budget only at approved split points or multi-session boundaries.
6. Place essential work in dependency order.
7. Place optional/stretch work only after essential work fits.
8. Preserve dependency order; mark expected-late instead of reordering to hide risk.
9. Return scheduled tasks and risk report even when infeasible.

The scheduler must not lower target depth, extend deadline, move existing active tasks, invent missing tasks, or create Today actions before activation.

Buffer details:

- If there are fewer than 3 usable normal-placement days, reserve 0 buffer days and record `no_buffer_available`.
- If there are 3-6 usable normal-placement days, reserve the latest 1 usable day.
- If there are 7 or more usable normal-placement days, reserve the latest `ceil(usable_days * 0.2)` usable days, clamped to 1-5 days.
- Reserved buffer days remain visible in `scheduled_days` with `reservedBuffer=true`.
- Normal placement first uses non-buffer execution budgets. If essential work can fit only by using reserved buffer, the scheduler may show that placement but must mark `buffer_erosion` and return `infeasible_review` until the user accepts buffer risk or changes constraints.

Placement details:

- Essential tasks are placed in compiler order after dependencies are satisfied.
- Optional and stretch tasks are attempted only after essential work has a feasible placement.
- A task may be placed on a date only when its dependencies are already completed on earlier sessions or earlier items on the same date.
- If no feasible date exists, keep the task in dependency order, record the first failed constraint, and include it in `unscheduled_tasks` or `expected_late_tasks`.

Load shapes change distribution, not scope:

- `balanced`: choose the date with the lowest planned-minutes-to-budget ratio; tie-break by earliest date.
- `front_loaded`: choose the earliest date with remaining execution budget.
- `light_start`: cap the first usable day at 50% of its planning budget; then use balanced placement with the same tie-breakers.

Load shapes never override dependency order, rest/unavailable dates, hard deadlines, or accepted/unaccepted overload rules.

Acceptance modes:

- Normal mode caps placement at `planningBudget(date)` and avoids reserved buffer.
- `accept_crunch` raises selected dates from 80% planning budget up to 100% of `usableCapacity(date)` and reruns scheduling. It does not exceed usable capacity.
- `accept_overload` permits planned minutes above `usableCapacity(date)` on explicitly selected dates and records those dates as overloaded.
- `accept_buffer_risk` permits using reserved buffer while keeping buffer erosion visible in the review package.

## Continuation Sessions

If a task estimate exceeds the normal planning budget for available days:

- split only at `splitPoints` or explicit multi-session boundaries;
- keep parent task id and sequence number;
- include session estimate and visible sub-output or continuation note;
- if no meaningful split exists, return expected-late, overload, or capacity-gap facts.

Split sessions inherit the parent task's classification and dependency constraints.
Downstream UI can render them as one task with dated sessions; the scheduler must
not create unrelated new tasks.

Fallback mode is review metadata, not a replacement for normal completion. A
scheduled item may expose compiler-provided fallback work with:

- `fallback_minutes`;
- `fallback_output`;
- `risk_effect`: `preserves_momentum`, `creates_follow_up`, or `changes_plan_risk`.

Fallback minutes do not count as completing the full scheduled item unless a
later adjustment or user choice explicitly converts the plan. That conversion is
outside this change.

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

`capacity_gap_minutes` is calculated against essential work first:

`max(0, essential_minutes - available_execution_minutes_before_unaccepted_buffer_or_overload)`.

Optional/stretch gaps are reported separately as `optional_unscheduled_minutes`.

`buffer_erosion` records the reserved buffer days or minutes consumed by normal
work before any explicit user acceptance. Buffer erosion can coexist with zero
capacity gap.

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
- `accept_crunch`: raise selected dates up to 100% of usable capacity and rerun scheduler.
- `accept_buffer_risk`: keep buffer erosion visible and return a review version that downstream activation can confirm explicitly.
- `rebalance`: rerun scheduler with same scope/depth/deadline/capacity and different distribution.
- `accept_overload`: keep overload visible and allow activation only after explicit confirmation.
- `edit_estimates`: keep task structure and rerun scheduler after estimate edits.
- `accept_rough_draft`: allow activation only if there are no blocking validation errors and assumptions stay visible.
- `store_for_later`: exit active planning and create no active tasks.
- `accept_late_finish`: allowed only for soft/assumed deadlines.

`reduce_scope` and `lower_depth` may require cooperation with the compiler, but the scheduler owns the before/after fit math and option availability.

Option effects are deterministic recomputation requests. They return a new
`ScheduledDraftReview` version or a storage/recompile request. They do not
silently activate the draft.

- `reduce_scope` reruns scheduling after removing scheduler-eligible optional or stretch work.
- `lower_depth` returns a `compiler_recompute_required` handoff with requested target depth, removed evidence preview, and current fit facts; compiler regeneration remains outside this change.
- `answer_one_question` returns a `compiler_recompute_required` handoff with the missing or low-calibration question.
- `edit_estimates` reruns scheduling with user-edited estimates while preserving task ids and dependencies.

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
