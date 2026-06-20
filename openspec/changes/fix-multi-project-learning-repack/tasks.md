## 1. Git Safety and Reproduction Baseline

- [x] 1.1 Re-run `git status --short --branch` in MalDaze and Hermes, inventory the existing `schedule.py`, deadline-test, learning-data, and LearningDeskPanel edits, and record which files are user-owned or overlap this change.
- [ ] 1.2 Before non-worktree apply, create user-approved scoped checkpoint commit(s) for relevant source/test state without including unrelated workspace changes; keep runtime learning JSON out of source checkpoints and create no schedule mutation yet.
- [x] 1.3 Capture the failing baseline with `schedule-range` showing aggregate 500+ minute days while `validate` reports valid, and preserve the current `projects.json` hash plus backup inventory as evidence.

## 2. Dynamic Cadence Planner (Hermes, RED → GREEN → REFACTOR)

- [x] 2.1 RED: add cadence tests for 25 tasks / 25 days, 19 / 23, 60 / 20, configured rest days, and review-task exclusion; run them and record the expected failures before implementation.
- [x] 2.2 GREEN: implement the minimal pure cumulative balanced-cadence helper using canonical task order until the cadence tests pass.
- [x] 2.3 RED: add global-planner tests for two active projects sharing 300 minutes, variable-duration tasks, fair interleaving, completed-task preservation, same-day completed fixed load, separate review capacity, and deterministic output; run and record failures.
- [x] 2.4 GREEN: implement the minimal pure global active-schedule planner with shared day capacity, cadence-deficit priority, deadline slack, and bounded look-ahead/backtracking until the planner tests pass.
- [x] 2.5 REFACTOR: remove isolated-capacity paths and duplicate ordering/capacity helpers while keeping all cadence and planner tests green.
- [x] 2.6 Run spec-compliance review for the planner scenarios, then code-quality review for determinism, complexity bounds, mutation safety, and actionable infeasibility diagnostics; resolve blocking findings before CLI integration.

## 3. Deadline and Initial Plan CLI Integration (Hermes, RED → GREEN → REFACTOR)

- [x] 3.1 RED: add `set-deadline` tests proving global active-project dry-run fields, cross-project changes, no dry-run writes, completed-date preservation, and exact dry-run/apply parity for an unchanged snapshot.
- [x] 3.2 RED: add infeasibility tests proving non-dry-run exits non-zero and atomically preserves both the old deadline and every task date.
- [x] 3.3 GREEN: route `set-deadline` through the pure planner and return additive `repack_scope`, `feasible`, `affected_project_ids`, `project_cadences`, project-tagged changes, and conflict fields.
- [x] 3.4 RED: add `plan` tests proving 60 tasks / 20 days begins from a three-task cadence and still subtracts all existing cross-project day load.
- [x] 3.5 GREEN: route initial `plan` placement through the balanced cadence calculation without moving already persisted other-project tasks.
- [x] 3.6 REFACTOR: retain explicit `--no-repack` compatibility, remove the default isolated/tight behavior and its contradictory regression test, and keep response compatibility tests green.
- [x] 3.7 Run spec-compliance and code-quality reviews for CLI behavior and resolve blocking findings before moving to validation/UI work.

## 4. Aggregate Validation (Hermes, RED → GREEN → REFACTOR)

- [x] 4.1 RED: add a regression where projects contribute 281 and 240 minutes to the same 300-minute day; assert `validate` fails and matches `schedule-range.over_capacity`.
- [x] 4.2 GREEN: make `validate` aggregate active-project study/review load through the same calendar-load helper used by `schedule-range`, including contributing project/task facts.
- [x] 4.3 REFACTOR: remove per-project capacity validation duplication while preserving deadline validation and existing single-project behavior.
- [x] 4.4 Run focused Hermes learning-assistant tests and both review stages; resolve every critical finding.

## 5. Deadline Preview Contract and UI (MalDaze, RED → GREEN → REFACTOR)

- [x] 5.1 RED: add decoding tests for the additive global-repack response, including cadence summaries, affected projects, project-tagged changes, feasible and infeasible payloads, plus compatibility with legacy fields.
- [x] 5.2 GREEN: extend Hermes schedule response models and CLI adapter without adding Swift-side schedule or capacity calculations.
- [x] 5.3 RED: add view-model/UI tests proving deadline editing dry-runs first, discloses cross-project impact, disables apply when infeasible, and refreshes all learning tabs after feasible apply.
- [x] 5.4 GREEN: implement the preview/confirmation and Hermes-authored conflict feedback with the minimal UI/model changes required by the tests.
- [x] 5.5 REFACTOR: centralize preview copy/formatting, preserve fail-loud behavior, and verify no local filtering, optimistic hiding, or shadow schedule state was introduced.
- [x] 5.6 Run MalDaze spec-compliance and code-quality reviews; resolve blocking findings before data repair.

## 6. Contract Documentation and Automated Verification

- [x] 6.1 Update the canonical Hermes integration learning-panel documentation with dynamic cadence, shared capacity, global deadline reconciliation, transactional infeasibility, and additive response fields.
- [x] 6.2 Run focused Hermes learning-assistant tests, relevant MalDaze unit tests, an Xcode build/test command proportional to the touched targets, `openspec validate fix-multi-project-learning-repack --strict`, and `git diff --check`; record exact results.
- [x] 6.3 Perform a final line-by-line spec-compliance review and code-quality review across Hermes and MalDaze; sync any implementation-discovered design correction back into the OpenSpec artifacts before proceeding.

## 7. User-Approved SSOT Recovery and Manual QA

- [ ] 7.1 Obtain explicit user confirmation before mutating the live learning SSOT, then create a fresh timestamped backup and record its path and hash.
- [ ] 7.2 Run same-deadline global dry-run against the live snapshot and verify: first LeetCode task stays completed on 2026-06-18, canonical pending order is unchanged, cadence facts match remaining tasks/days, Saturday is empty, and every study day is at or below 300 minutes.
- [ ] 7.3 Apply the verified plan once through Hermes, never by hand-editing JSON, then run `validate`, `schedule-range`, and `status` to prove aggregate capacity, deadlines, progress, and next-task results.
- [ ] 7.4 Manually QA MalDaze Today, Schedule, and Project tabs against the same SSOT, including preview disclosure, over-capacity styling, task order, deadlines, and refresh after apply.

## 8. Completion and Branch Finalization

- [x] 8.1 Invoke verification-before-completion and rerun all fresh required checks; do not claim the bug fixed if any expected result is missing.
- [ ] 8.2 Invoke finishing-a-development-branch and present merge, PR, keep, or discard options; clean up a worktree only after the user chooses the finalization path.
