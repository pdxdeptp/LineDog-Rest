## Why

Hermes currently can repack each active learning project against an isolated copy of the daily budget, so individually valid plans combine into 500+ minute days even though the global study budget is 300 minutes. Repack also needs a dynamic project cadence: one lesson per study day is correct for 25 lessons over 25 days, while 60 lessons over 20 days requires an even target of three lessons per day before cross-project capacity reconciliation.

## What Changes

- Derive each project's daily lesson cadence during initial planning and repack from its remaining ordered study tasks and remaining eligible study days, distributing task counts as evenly as possible across the project window instead of imposing a fixed one-lesson rule or packing every day to capacity.
- Treat `daily_capacity_minutes` as one hard study-minute ceiling shared by all active projects; review tasks continue to use the separate review budget.
- Reconcile project cadences deterministically across the shared calendar, preserving canonical lesson order, completed dates, configured rest days, and deadline urgency without starving a project.
- **BREAKING**: deadline repack becomes a global active-schedule reconciliation from today, so changing one active project's deadline may move incomplete tasks in other active projects when required to maintain shared capacity and balanced cadence.
- Make `set-deadline --dry-run` report all affected projects, per-project cadence facts, moves, and infeasibility before any write; MalDaze must explain the wider impact before confirmation.
- Make validation aggregate study and review load across active projects so `validate` and `schedule-range.over_capacity` cannot disagree.
- Refuse to silently create an over-capacity schedule. If all work cannot fit before project deadlines, return explicit overflow/deadline-risk facts while preserving the last valid persisted schedule.
- After the algorithm and regression tests pass, repair the current `projects.json` through the Hermes command path from a fresh backup; do not hand-edit dates or add MalDaze-side filtering.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `hermes-learning-calendar`: Replace isolated/tight per-project repack with balanced dynamic cadence and shared cross-project capacity reconciliation; align validation and dry-run/apply behavior.
- `learning-desk-panel`: Update deadline-repack preview and confirmation to disclose cross-project changes and render Hermes-authored feasibility results without computing schedule dates locally.

## Impact

- **Hermes**: `~/.hermes/scripts/schedule.py`, learning-assistant scheduling tests, CLI response fields, and the current learning schedule data recovery workflow.
- **MalDaze**: deadline preview/response models and confirmation/feedback copy only where required by the expanded Hermes response; the calendar and schedule SSOT remain Hermes-owned.
- **Contracts**: `projects.json` remains the sole task/date SSOT; `profile.json.daily_capacity_minutes` remains the single global study-capacity setting.
- **Compatibility**: completed tasks and their dates remain unchanged. Existing callers that only inspect the original `set-deadline` response fields remain valid, while MalDaze adopts additive cross-project preview fields.
