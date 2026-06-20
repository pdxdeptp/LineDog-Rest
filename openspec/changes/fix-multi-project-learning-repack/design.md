## Context

Hermes owns learning dates and capacity policy in `schedule.py`; `projects.json` is the task/date SSOT and MalDaze only invokes documented CLI commands. The current repack worktree can exclude every other project's pending load and tightly fill each project to 300 minutes independently. `schedule-range` then correctly aggregates 500+ minute days, while `validate` incorrectly reports success because it validates each project in isolation.

The desired cadence is neither a fixed one lesson per day nor “fill the whole budget as early as possible.” It is derived per project from remaining lesson count and remaining eligible study days, then reconciled across all active projects under one global minute budget. The current data illustrates the intended result: 25 remaining LeetCode lessons over 25 study days yields one per day; 19 agent chapters over 23 study days yields nineteen one-chapter days and four distributed gaps; 60 lessons over 20 days yields three per day before duration conflicts are considered.

## Goals / Non-Goals

**Goals:**

- Produce a deterministic, balanced per-project cadence from remaining study-task count and project window.
- Keep aggregate active-project study load at or below `daily_capacity_minutes` on every non-rest day.
- Preserve canonical task order and leave completed tasks and historical dates unchanged.
- Make deadline repack order-independent by reconciling the whole active schedule rather than giving each project a private capacity budget.
- Make dry-run and apply use the same pure planning result, with transactional failure when the requested deadlines are infeasible.
- Make `validate` and `schedule-range` use the same aggregate capacity definition.

**Non-Goals:**

- Replacing `projects.json`, introducing a MalDaze cache, or computing dates in Swift.
- Adding external-calendar projection, hour-by-hour time blocks, or manual project-priority controls.
- Changing the separate `review_budget_minutes` policy or counting review tasks as course lessons for cadence.
- Automatically rewriting schedules in the background without an explicit Hermes write command and preview/confirmation where MalDaze initiates the write.

## Decisions

### D1: Use one pure planning core for plan previews and repack

Implement a pure planner that accepts a snapshot of projects, profile, planning start date, and proposed metadata changes, and returns a candidate schedule plus diagnostics without writing files. `set-deadline --dry-run` returns this result; apply persists that same result only when it is feasible. Initial `plan` uses the same cadence calculation for the new project's candidates while treating already persisted other-project dates as occupied shared capacity.

This separates calculation from persistence and prevents preview/apply drift. Keeping schedule calculation in Hermes also preserves the existing SSOT boundary.

### D2: Define cadence through cumulative balanced targets

For each active project, let `N` be remaining pending non-review tasks and `D` be eligible non-rest days from the planning start through its deadline. For study day index `i` in `1...D`, the cumulative preferred task count is:

`preferred(i) = ceil(i * N / D)`

The preferred count for a single day is the difference between consecutive cumulative values. Therefore each day receives either `floor(N / D)` or `ceil(N / D)` project tasks, heavier days are distributed deterministically, and the first task is not needlessly delayed. Examples:

- `25 / 25` → one lesson on every study day.
- `19 / 23` → nineteen one-lesson days plus four distributed zero-lesson days.
- `60 / 20` → three lessons on every study day.

These counts are soft cadence targets. Task durations, global capacity, rest days, and deadlines are hard constraints.

### D3: Reconcile all active projects with a shared fair queue

Deadline repack clears only incomplete active-project assignments from the candidate snapshot and rebuilds them together. On each eligible day, the planner compares each project's cumulative preferred count with its assigned count. Projects with the greatest cadence deficit are considered first; ties use less remaining deadline slack, earlier deadline, then stable project id. After placing one canonical next task, priority is recalculated so one project cannot drain the day before another due project is considered.

A task is placed only if its full `duration_minutes` fits the day's remaining global study capacity. When a due task does not fit, another due project may use the remaining capacity and the skipped project carries its deficit forward. Preferred dates may shift earlier or later when needed, but project task order may not invert and no day may exceed capacity. A bounded look-ahead/backtracking fallback SHALL be used before declaring infeasibility so simple duration packing conflicts do not produce a false overflow.

Reviews are excluded from `N` and use the existing separate review bucket. Completed tasks are never moved; completed work already recorded on the planning start day remains fixed load for that day.

### D4: Deadline edits reconcile the global active schedule

Because capacity is global, changing one active deadline can change the feasible cadence of every active project. `set-deadline` therefore previews and, after confirmation, applies one global active-set reconciliation from today. This intentionally replaces the target-project-only behavior.

The response keeps existing fields and adds:

- `repack_scope: "all_active"`
- `feasible`
- `affected_project_ids[]`
- `project_cadences[]` with remaining study-task count, eligible-day count, minimum/maximum preferred daily count, and moved-task count
- `changes[].project_id`
- structured `capacity_conflicts[]` / `overflow_tasks[]` when infeasible

MalDaze renders these Hermes-authored facts and does not infer dates or capacity locally.

### D5: Infeasible apply is transactional and fail-loud

If any task cannot fit by its deadline under rest-day, ordering, duration, and shared-capacity constraints, the planner returns `feasible: false`. Dry-run writes nothing as usual. Non-dry-run `set-deadline` also writes neither the new deadline nor partial task dates and exits non-zero, preserving the previous persisted snapshot. The response identifies affected projects and overflow tasks so the user can extend a deadline, increase capacity, or reduce scope.

This is safer than keeping old dates for overflow tasks, which can persist the exact over-capacity schedule the operation was meant to repair.

### D6: Validate capacity once, across the active calendar

`validate` aggregates pending study and review minutes by date across all active projects, using the same helpers as `schedule-range`. Capacity issues remain attributable by listing contributing project/task ids, but the pass/fail decision is global. This removes the current state where `schedule-range.over_capacity` is true and `validate.valid` is also true.

### D7: Repair current data only after code verification

The existing backup is evidence, not a restore target, because it already contains extreme date stacking. After RED/GREEN tests, focused Hermes tests, OpenSpec validation, and MalDaze contract tests pass:

1. Create a fresh timestamped backup of `projects.json`.
2. Run same-deadline dry-runs for the active schedule and inspect cadence, affected projects, capacity, order, and completion preservation.
3. Apply once through Hermes after explicit user confirmation.
4. Run `validate`, `schedule-range`, `status`, and MalDaze manual QA against the written SSOT.

Rollback, if requested, restores the fresh pre-apply backup only; it never uses a silent client-side filter.

## Risks / Trade-offs

- **[Risk] A deadline edit moves another project's pending tasks** → MalDaze shows affected project count and cadence summary before confirmation; completed work never moves.
- **[Risk] Count-balanced cadence can still have uneven minutes because lessons vary in duration** → counts remain the user-facing pacing target, while shared minutes are the hard constraint and may shift individual target dates.
- **[Risk] A greedy fair queue can report false infeasibility** → use bounded look-ahead/backtracking and regression fixtures with variable task sizes and competing deadlines.
- **[Risk] Global reconciliation increases the change set** → calculate on a copy, keep writes atomic, return per-project diffs, and back up the SSOT before the one-time recovery.
- **[Risk] Existing callers assume `changes[]` belongs only to the edited project** → keep old fields additive, add `project_id` to every change, and update MalDaze decoding before enabling global apply from the panel.

## Migration Plan

1. Add failing pure-planner tests for balanced cadence, global capacity, fairness, canonical ordering, infeasibility, and preview/apply atomicity.
2. Implement the shared planner and switch `set-deadline`, then align `plan` cadence behavior.
3. Make global validation reuse aggregate load helpers and add the cross-project regression.
4. Extend the additive CLI response and MalDaze preview/confirmation models and copy.
5. Run focused and full relevant test suites, then perform the backed-up data repair and manual schedule-panel QA.
6. If code rollout must be reverted, revert code and restore the fresh pre-repair JSON backup only with explicit user approval.

## Open Questions

None. The confirmed product rule is dynamic balanced cadence per project, reconciled under one global capacity ceiling.
