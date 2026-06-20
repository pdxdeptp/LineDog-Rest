## 1. OpenSpec and Baseline

- [ ] 1.1 Run `openspec validate redesign-learning-pacing-planner --strict` after artifacts are complete.
- [ ] 1.2 Capture current live snapshot metrics (per-project ideal cadence expectation vs actual, capacity conflicts) as RED baseline evidence.

## 2. Spine Builder (Hermes, RED → GREEN)

- [x] 2.1 RED: tests for `build_project_spine` — 25/25, 19/23, 60/20, rest days, review exclusion, first-task-not-delayed.
- [x] 2.2 GREEN: implement pure `build_project_spine(project, profile, from_date)` returning ordered `{task_id, ideal_date}`.
- [x] 2.3 RED: tests proving ideal dates use the full window (last ideal date near deadline, not clustered in first week).

## 3. Merge and Feasibility (Hermes, RED → GREEN)

- [x] 3.1 RED: tests for `merge_spines_and_check` with lc_review + hello_agents-like fixtures — feasible spread; infeasible when ideal overlap exceeds 300 minutes.
- [x] 3.2 GREEN: implement merge overlay and fail-loud feasibility (no task sliding, no extra lessons per day).
- [x] 3.3 RED: tests that infeasible result includes `capacity_conflicts[]`, `feasible: false`, and no partial assignment.
- [x] 3.4 GREEN: wire review placement after feasible study merge; fail if review budget cannot be satisfied without moving study tasks.

## 4. Replace Global Planner (Hermes, RED → GREEN → REFACTOR)

- [x] 4.1 RED: replace greedy-planner regression tests with spine-based expectations on real fixture snapshots.
- [x] 4.2 GREEN: reimplement `plan_global_active_schedule` as spine → merge → check; remove fair-queue front-loading paths.
- [ ] 4.3 GREEN: route `set-deadline` and `plan` through the new pipeline; keep transactional infeasible apply and additive response fields.
- [ ] 4.4 REFACTOR: delete unused fair-queue / overflow backfill helpers; keep `fix-multi-project-learning-repack` validate aggregation untouched.

## 5. CLI Diagnostics (Hermes + MalDaze)

- [ ] 5.1 RED: tests for infeasible payload fields (`capacity_conflicts`, remedy hints) and feasible ideal-date `changes[]`.
- [ ] 5.2 GREEN: extend CLI JSON; decode tests in MalDaze.
- [ ] 5.3 GREEN: update deadline/repack sheet copy — infeasible →「需延长截止日或提高每日容量」; block confirm.

## 6. Verification and Data

- [ ] 6.1 Run full Hermes learning-assistant tests and focused MalDaze tests; record exact results.
- [ ] 6.2 Dry-run live snapshot; if infeasible, document which deadline extensions unblock it; apply only with user approval after feasible dry-run.
- [ ] 6.3 Manual QA: Today / Schedule / Project tabs; confirm 1-lesson-per-day LeetCode spread when feasible.

## 7. Completion

- [ ] 7.1 Sync OpenSpec if implementation discovers spec gaps.
- [ ] 7.2 Present branch finalization options after all checks pass.
