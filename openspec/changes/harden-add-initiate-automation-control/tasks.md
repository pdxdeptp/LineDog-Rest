## 1. Three-Round State Alignment

- [x] 1.1 Update `state.json` so required product-deepen rounds is 3 and the current checkpoint is `product_deepen_round_3` when only two rounds are complete.
- [x] 1.2 Update `runbook.md` and `progress.md` so the documented state machine, per-run limits, completion evidence, and current status match three product-deepen rounds.
- [x] 1.3 Update automation `add-initiate-changes` prompt to match the local control files.

## 2. Migration Evidence

- [x] 2.1 Add machine-readable migration evidence for the two-round to three-round transition.
- [x] 2.2 Add a progress log entry explaining the migration and next checkpoint.

## 3. Resumable Apply Tracking

- [x] 3.1 Add apply task-group tracking fields to `state.json` for all five controlled changes.
- [x] 3.2 Update `runbook.md` with apply task-group resume, evidence, and advancement rules.

## 4. Workspace Safety Baseline

- [x] 4.1 Add a workspace safety baseline file that records accepted pre-existing paths and automation-owned paths.
- [x] 4.2 Update `runbook.md` with baseline comparison and staging rules for dirty worktrees.

## 5. Verification

- [x] 5.1 Run `openspec validate harden-add-initiate-automation-control --strict`.
- [x] 5.2 Verify the control files contain no remaining two-round state-machine references.

## 6. Stale Lock Recovery

- [x] 6.1 Add automatic stale lock quarantine and recovery rules that do not require manual unlock.
- [x] 6.2 Add lock recovery evidence schema and state fields.
- [x] 6.3 Update automation prompt lock summary to match stale lock recovery.

## 7. Heartbeat Interval

- [x] 7.1 Change automation `add-initiate-changes` heartbeat interval from 5 minutes to 10 minutes.

## 8. Structured Failures

- [x] 8.1 Add structured failure log path and `lastFailure` state field.
- [x] 8.2 Update runbook retry/blocking rules to require JSONL failure entries.
- [x] 8.3 Add failure evidence schema.

## 9. Machine-Readable Evidence

- [x] 9.1 Add evidence manifest path to `state.json`.
- [x] 9.2 Add initial `evidence/manifest.json` entries for completed rounds and migration.
- [x] 9.3 Update idempotency rules to trust the manifest before Markdown evidence.

## 10. Checkpoint Commit Policy

- [x] 10.1 Add pre-apply checkpoint commit policy to state.
- [x] 10.2 Update runbook with safe staging, commit evidence, and commit-blocked behavior.
- [x] 10.3 Add commit evidence schema.

## 11. Cross-Change Contracts

- [x] 11.1 Add cross-change contract state and evidence root.
- [x] 11.2 Update apply completion rules to require downstream contract checks before advancing.
- [x] 11.3 Add cross-change contract evidence schema.

## 12. Scope Dependency Check

- [x] 12.1 Add `scope_dependency_check` between product deepening and apply.
- [x] 12.2 Add per-change scope dependency state fields.
- [x] 12.3 Add scope dependency evidence schema and manifest support.
- [x] 12.4 Update runbook and progress to include the new checkpoint.
- [x] 12.5 Require every product-deepen round to consider adjacent change scope and record scope decisions.

## 13. Remove Standalone Pre-Apply Gate

- [x] 13.1 Remove the standalone pre-apply gate from the state machine, state flags, runbook, progress, and evidence manifest.
- [x] 13.2 Move apply task-group planning into the `apply` stage preflight.
- [x] 13.3 Update the heartbeat automation prompt to move directly from `scope_dependency_check` to `apply`.
