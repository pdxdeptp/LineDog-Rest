## Context

`fix-multi-project-learning-repack` introduced global capacity reconciliation and balanced cadence math, but implemented pacing as a **soft** target inside a greedy day-by-day fair queue. That queue minimizes unused capacity early, which front-loads work and stacks lessons when projects compete.

The user confirmed the product rule for conflicts:

> **Do not compromise the schedule silently. Report infeasible and ask the user to extend a deadline** (or otherwise change inputs: capacity, scope).

MalDaze remains a contract consumer; Hermes owns all date assignment.

## Goals / Non-Goals

**Goals:**

- Assign each pending study task an **ideal calendar date** from per-project balanced cadence spread across the full eligible window (not "as early as possible").
- Merge all active projects on one shared calendar while preserving per-project ideal dates when possible.
- If merged ideal dates violate shared capacity or cannot keep hard cadence within deadlines, return **`feasible: false`** with actionable conflict facts.
- Preserve: canonical order, completed tasks, rest days, separate review budget, global validate, transactional apply, dry-run/apply parity.

**Non-Goals:**

- Auto-stacking multiple lessons on one day to "make it fit".
- Sliding tasks earlier to finish weeks before deadline.
- Limited automatic deviation / "best effort" partial schedules on apply.
- MalDaze-side date math or shadow schedules.
- User priority controls between projects.

## Decisions

### D1: Three-phase pipeline replaces fair queue

| Phase | Name | Output |
|-------|------|--------|
| A | `build_project_spine` | Per project: map each pending study task → `ideal_date` on balanced cadence |
| B | `merge_spines` | Overlay all projects; compute per-day study/review minutes at ideal dates |
| C | `check_feasibility` | If any day > capacity OR any project cannot place all tasks on ideal spine within deadline → infeasible |

No phase C "resolver" that moves tasks. **Merge is read-only; conflicts fail.**

**Alternative rejected**: slide tasks later within window — user chose fail-loud instead to avoid hidden compromises.

### D2: Hard cadence via ideal dates (not soft deficit)

For project with `N` study tasks and eligible days `d[0..D-1]`:

```
cumulative(i) = ceil(i * N / D)
task k ideal index = min i where cumulative(i) >= k
ideal_date(task k) = d[ideal_index]
```

Examples (unchanged from prior design):
- 25/25 → one distinct ideal date per task across the window
- 19/23 → nineteen ideal dates with four eligible days unused
- 60/20 → three tasks share each ideal day index

Cadence is **hard**: planner output must match ideal per-day counts unless inputs are infeasible (then no output write).

### D3: Conflict → infeasible (user extends deadline)

Feasibility fails when **any** of:

1. **Capacity conflict**: sum of study minutes on an ideal date across active projects exceeds `daily_capacity_minutes` (reviews checked against `review_budget_minutes`).
2. **Cadence spill**: cannot assign every task its ideal date before project deadline (should not occur if spine uses full window; included for safety).
3. **Order/coverage**: incomplete task would remain unassigned.

On infeasible `set-deadline` apply: same transactional rule as today — no deadline change, no task date change, exit non-zero.

Dry-run returns:
- `feasible: false`
- `capacity_conflicts[]` with date, load, capacity, contributing tasks/projects
- `cadence_conflicts[]` when ideal spine cannot be honored (if applicable)
- `suggested_remedies[]` e.g. `extend_deadline`, `increase_daily_capacity` (informational strings only)

**User action**: extend one or more project deadlines, reduce pending tasks, or raise capacity — then dry-run again.

### D4: Reviews after study spine

Review tasks excluded from `N`. After feasible study placement is confirmed, place reviews on their ideal or earliest fitting day within review budget. If review placement fails → infeasible (same fail-loud rule).

### D5: `plan` uses same spine for new project only

`plan` builds spine for candidate tasks, merges against **persisted** other-project dates as fixed occupancy. If merge infeasible → `overflow` all candidates (or entire plan fails with explicit overflow reason). Does not move other projects' tasks.

### D6: CLI/MalDaze preview copy

MalDaze shows Hermes conflict facts verbatim. Primary CTA when infeasible: user adjusts deadline in the same sheet and re-previews. No "apply anyway".

## Risks / Trade-offs

- **[Risk] Stricter planner rejects schedules that old planner squeezed through** → Expected; preview explains why; user extends deadline.
- **[Risk] Two 90-minute Agent chapters on same ideal day as LeetCode may often infeasible** → Correct behavior under fail-loud; user extends Agent or LeetCode deadline or lowers Agent chapter load via scope change.
- **[Risk] Users expect automatic fix** → Preview copy must say clearly: "无法在不延截止日的情况下排开".

## Migration Plan

1. Implement spine + merge + feasibility behind tests using live-like fixtures (lc_review + hello_agents).
2. Replace `plan_global_active_schedule` internals; keep response envelope from `fix-multi-project-learning-repack`.
3. User dry-run repack; if infeasible, extend deadline(s); apply when feasible.
4. Rollback: revert code; restore JSON backup if apply occurred.

## Open Questions

None. Conflict policy is **fail-loud; user extends deadline**.
