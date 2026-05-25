# Add / Initiate Implementation Automation Runbook

## Source Of Truth

- `state.json` is the only source of the current phase, change, and checkpoint.
- `progress.md` is an append-only run log plus an in-place `## Current Status` summary.
- Chat history and old heartbeat text are not authoritative.

## Locking

Use `openspec/add-initiate-implementation-control/run.lock` as an atomic directory lock.

Start of every run:

1. Attempt to create `run.lock` as a directory.
2. If it already exists, read `run.lock/lock.json` when available.
3. If the lock is not stale, append a progress entry and stop without changing checkpoint state.
4. If the lock is stale, automatically recover it:
   - confirm the lock age is greater than `state.json.lock.staleAfterMinutes` using `lock.json.startedAt` when present, otherwise the lock directory mtime;
   - create `openspec/add-initiate-implementation-control/recovered-locks/` if needed;
   - atomically move `run.lock` to `recovered-locks/run.lock.<UTC timestamp>`;
   - write recovery evidence to `openspec/add-initiate-implementation-control/evidence/lock-recovery/<UTC timestamp>.md`;
   - update `state.json.lock.lastRecovery`;
   - attempt to create a fresh `run.lock` and continue the run.
5. Do not delete stale locks; only move them to `recovered-locks/` with evidence.
6. If stale lock recovery fails, set `phase=blocked`, write structured failure details, append progress, and stop.
7. If lock creation succeeds, immediately write `run.lock/lock.json` with:
   - `startedAt`
   - `runCounter`
   - `currentChange`
   - `currentStep`
   - `currentCheckpoint`
   - `automationId`
   - `heartbeatUpdatedAt`

End of every safe run:

- Remove only the lock created by this run.
- If the run crashes or hits an unsafe state, leave the lock in place. Later runs may auto-recover it only after it becomes stale by the rule above.

## Checkpoint State Machine

Each change moves through:

1. `product_deepen_round_1`
2. `product_deepen_round_2`
3. `product_deepen_round_3`
4. `apply_readiness`
5. `apply`
6. `completed`

The fixed change order is:

1. `introduce-study-intake-router`
2. `persist-intake-plan-drafts`
3. `introduce-plan-compiler`
4. `introduce-deadline-scheduler`
5. `redesign-add-initiate-ui`

## Per-Run Limit

Each heartbeat run may advance at most one non-product-deepen checkpoint, or up to three consecutive product-deepen checkpoints for the same change:

- up to three product-deepen rounds, stopping at `product_deepen_round_3`;
- one apply-readiness review, or
- one independently verifiable apply task group.

Do not cross into apply-readiness or the next change in the same heartbeat run after finishing product-deepen round 3. If a checkpoint finishes, update `state.json` and let the next heartbeat continue unless the only remaining work in the current run is the next product-deepen round for the same change.

## Completion Evidence

`product_deepen_round_1` is complete only when:

- `opsx-product-deepen` has been run for the current change;
- findings and modifications are recorded in `openspec/changes/<change>/review-records/product-deepen-round-1.md`;
- any changed OpenSpec artifacts validate with `openspec validate <change> --strict`;
- `state.json` increments `productDeepenRoundsCompleted` to 1.

`product_deepen_round_2` is complete only when:

- `opsx-product-deepen` has been run again after round 1;
- review quality and remaining gaps are recorded in `openspec/changes/<change>/review-records/product-deepen-round-2.md`;
- any changed OpenSpec artifacts validate with `openspec validate <change> --strict`;
- `state.json` increments `productDeepenRoundsCompleted` to 2.

`product_deepen_round_3` is complete only when:

- `opsx-product-deepen` has been run again after round 2;
- final product-readiness findings and any remaining accepted risks are recorded in `openspec/changes/<change>/review-records/product-deepen-round-3.md`;
- any changed OpenSpec artifacts validate with `openspec validate <change> --strict`;
- `state.json` increments `productDeepenRoundsCompleted` to 3.

`apply_readiness` is complete only when:

- `opsx-apply-readiness` has been run for the current change;
- readiness result is recorded in `openspec/add-initiate-implementation-control/evidence/<change>/apply-readiness.md`;
- apply task groups are recorded in `openspec/add-initiate-implementation-control/evidence/<change>/apply-task-groups.json`;
- `state.json` sets `changes[].applyTaskGroups.status=planned`, points `taskGroupsFile` at that JSON file, and initializes the top-level `applyCursor` for the current change;
- blockers are either absent or resolved;
- `openspec validate <change> --strict` passes;
- `state.json` sets `applyReadinessCompleted=true`.

`apply` is complete only when:

- `openspec-apply-change` or the project-approved opsx apply skill has run;
- subagent-driven development and per-task TDD gates were followed;
- relevant tests and `openspec validate <change> --strict` pass fresh;
- evidence is recorded under `openspec/add-initiate-implementation-control/evidence/<change>/`;
- all tasks in the change are complete or explicitly accepted as verification-only tasks;
- safe commits have been made or the state clearly records why commits are pending;
- `state.json` records `applyCursor.currentGroupId` before starting a group and moves that id to `completedGroupIds` only after fresh tests, strict OpenSpec validation, evidence, and any safe commit are recorded;
- cross-change contract checks pass for downstream Add / Initiate changes before advancing to the next change;
- `state.json` sets `applyCompleted=true` and the change status to `completed`.

## Apply Task Group Cursor

Before the first apply run for a change, `apply_readiness` must write `openspec/add-initiate-implementation-control/evidence/<change>/apply-task-groups.json`.

That file must contain:

- `changeId`
- `generatedAt`
- `groups[]`, where each group has `id`, `taskIds`, `description`, `targetFiles`, `testCommands`, `evidenceFile`, and `dependsOn`

During apply:

1. Pick the first group whose dependencies and previous groups are complete.
2. Set top-level `applyCursor.activeChange`, `currentGroupId`, `currentGroupStartedAt`, and `taskGroupsFile` before editing or testing that group.
3. Write group evidence under `openspec/add-initiate-implementation-control/evidence/<change>/apply-groups/<group-id>.md`.
4. After fresh verification, update both top-level `applyCursor.completedGroupIds` and the matching `changes[].applyTaskGroups.completedGroupIds`.
5. Clear `currentGroupId` only after the group is fully verified.
6. If a group blocks, set `applyCursor.blockedGroupId`, keep `currentGroupId`, write `blockedReason`, and stop.

Never infer apply progress from checked task boxes alone. The cursor and per-group evidence are the durable recovery record.

## Cross-Change Contract Checks

After a change's apply groups are complete, and before advancing to the next change:

1. Identify downstream changes from `state.json.crossChangeContracts.changeOrder`.
2. Read the completed change's final specs/tasks and the next change's proposal/design/specs/tasks.
3. Verify that handoff payloads, persisted entities, enum values, user-facing states, and test expectations required by downstream changes still match the completed change.
4. Run `openspec validate <completed-change> --strict` and `openspec validate <next-change> --strict` for the immediate next change.
5. Write evidence to `openspec/add-initiate-implementation-control/evidence/cross-change-contracts/<completed-change>-to-<next-change>.md`.
6. Append a `cross_change_contract` entry to `evidence/manifest.json`.
7. Update `state.json.crossChangeContracts.lastCheck`.
8. If the check fails, write a structured `contract_check_failed` failure and stop before moving to the next change.

For the final change, write `redesign-add-initiate-ui-final.md` confirming no downstream change remains.

## Idempotency

At the start of a run, if state says a checkpoint is current but evidence suggests it already completed:

1. Read `openspec/add-initiate-implementation-control/evidence/manifest.json` and locate the latest entry for the checkpoint.
2. Verify the evidence with fresh commands.
3. Confirm each `artifacts[].path` exists and each recorded `sha256` still matches when a hash is present.
4. If evidence is valid, update `state.json` to the next checkpoint and append a progress entry.
5. If evidence is missing or inconclusive, redo only the current checkpoint.

Never repeat an apply task group that already has verified evidence and committed changes unless a later review says it is incomplete. If checked task boxes, commits, and `applyCursor` disagree, stop and reconcile them in progress/evidence before continuing.

## Evidence Manifest

Every completed checkpoint, migration, stale lock recovery, apply group, cross-change contract check, and final report must append a machine-readable entry to `openspec/add-initiate-implementation-control/evidence/manifest.json`.

Each manifest entry must include:

- `id`
- `timestamp`
- `kind`: `checkpoint`, `migration`, `lock_recovery`, `apply_group`, `cross_change_contract`, or `final_report`
- `changeId`
- `checkpoint`
- `result`
- `commands[]` with `command`, `exitCode`, and `summary`
- `artifacts[]` with `path`, `sha256`, and `description`
- `nextCheckpoint`

Markdown evidence is for humans; the manifest is the recovery index automation must trust first.

## Retry And Blocking

- `currentAttempt` increments when retrying the same checkpoint after a recoverable failure.
- Every failure must append one JSON line to `openspec/add-initiate-implementation-control/evidence/failures/failure-log.jsonl` before retrying or blocking.
- After `maxRetriesPerCheckpoint` failures, set `phase=blocked`, write `blockedReason`, update `state.json.lastFailure`, append progress, and stop.
- `blockedReason` is a short human summary only; `lastFailure` and `failure-log.jsonl` are the durable recovery record.
- Block immediately on:
  - overlapping uncommitted user changes;
  - missing `tasks.md`;
  - missing failing test before implementation;
  - OpenSpec validation failure that cannot be fixed inside current scope;
  - repeated test failures;
  - app startup failure twice;
  - scope expansion or design contradiction;
  - need for worktree/isolation;
  - non-stale lock present or stale lock recovery failure.

## Structured Failure Records

Each failure JSONL entry must include:

- `timestamp`
- `automationId`
- `runCounter`
- `currentChange`
- `currentCheckpoint`
- `checkpointAttempt`
- `stage`: `lock`, `git_safety`, `product_deepen`, `apply_readiness`, `apply`, `verification`, `commit`, `cross_change_contract`, or `finalization`
- `category`: `stale_lock_recovery_failed`, `non_stale_lock_present`, `overlapping_user_changes`, `missing_artifact`, `openspec_validate_failed`, `test_failed`, `app_start_failed`, `scope_drift`, `design_conflict`, `worktree_required`, `commit_blocked`, `contract_check_failed`, or `unknown`
- `summary`
- `retryable`
- `command`
- `exitCode`
- `paths`
- `evidenceFile`
- `nextAction`

When `phase=blocked`, copy the latest entry into `state.json.lastFailure`.

## Git Safety

- Always run `git status` after acquiring the lock.
- Never reset, revert, merge, rebase, stash, or use worktrees.
- Read `openspec/add-initiate-implementation-control/workspace-baseline.json` before deciding whether a dirty working tree is blocking.
- Treat only the baseline entries in that file as expected pre-existing dirt; any other modified, deleted, renamed, or untracked path is new user work unless proven checkpoint-related.
- Expected baseline entries do not grant permission to overwrite. If the current checkpoint needs to edit a baseline path outside its own change/control scope, stop and ask.
- Only stage files related to the current checkpoint and listed in that checkpoint evidence.
- Never stage runtime SQLite/WAL/SHM, DerivedData, screenshots, logs, or unrelated user changes.

## Checkpoint Commit Strategy

Before the first `apply` checkpoint for any change:

1. Confirm `apply_readiness` has completed and `apply-task-groups.json` exists.
2. Create a safe checkpoint commit that includes only:
   - the current change's OpenSpec artifacts;
   - automation control/evidence files needed to resume;
   - any already-approved spec artifacts directly referenced by the current checkpoint evidence.
3. Record the commit hash, staged path list, and verification commands in `openspec/add-initiate-implementation-control/evidence/commits/<change>-pre-apply-checkpoint.md`.
4. Update `state.json.commitPolicy.lastCheckpointCommit`.
5. If a safe checkpoint commit cannot be created because of uncovered user changes, overlapping baseline paths, or ambiguous staging, do not start implementation. Set `phase=blocked`, write a structured `commit_blocked` failure, and stop.

During apply task groups:

- Prefer one small commit per independently verifiable apply group when tests and strict OpenSpec validation pass.
- If commits are intentionally deferred, write explicit deferral evidence with the reason, dirty paths, and next safe commit point; update `commitPolicy.pendingCommitReason`.
- Never use broad staging such as `git add .` or directory-wide staging for apply work.

## Workspace Baseline

The workspace may intentionally start dirty because this automation is orchestrating several OpenSpec changes from the current checkout. The baseline manifest prevents false blocking while still protecting user work.

At the start of a run:

1. Run `git status --porcelain=v1`.
2. Load `workspace-baseline.json`.
3. Compare current dirty paths with `expectedPreexistingEntries`.
4. If all dirty paths are covered by the baseline or are files created by the current checkpoint evidence, continue.
5. If any dirty path is not covered, or a baseline path is modified in a way unrelated to the current checkpoint, set `phase=blocked`, record the path, and stop.

Before staging:

1. Build an explicit staging list from current checkpoint evidence.
2. Exclude anything matching `neverStageGlobs` from the baseline.
3. Record the final staged path list in progress/evidence.
4. Do not stage broad directories.

## Done State

When all five changes are complete:

1. Set `phase=done`.
2. Write a final implementation report under `openspec/add-initiate-implementation-control/final-report.md`.
3. Append a final progress entry.
4. Pause automation `add-initiate-changes`.
