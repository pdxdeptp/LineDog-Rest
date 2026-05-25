# Add / Initiate Automation Runbook

This file is the short execution path. Field-level schemas live under
`openspec/add-initiate-implementation-control/evidence/**/schema.md`.

## Read First

- `state.json`: only source for phase, current change, checkpoint, retry count, lock policy, apply cursor, commit policy, and cross-change policy.
- `progress.md`: human summary plus append-only run log.
- `evidence/manifest.json`: machine-readable recovery index for completed checkpoints and migrations.
- `workspace-baseline.json`: known dirty workspace baseline and never-stage globs.
- Chat history and old heartbeat text are not authoritative.

## One Run Algorithm

1. Acquire or recover `run.lock`.
2. Read `state.json`, `progress.md`, `evidence/manifest.json`, and `workspace-baseline.json`.
3. Run `git status --porcelain=v1` and apply the baseline rules.
4. Execute only the checkpoint allowed by `currentStep`.
5. Run fresh verification for that checkpoint.
6. Write required evidence, append `evidence/manifest.json`, update `state.json`, and update `progress.md`.
7. Release only the lock created by this run.

If any step hits a stop rule, write a structured failure first, then stop.

## Locking

- Lock path: `openspec/add-initiate-implementation-control/run.lock`.
- Fresh lock: create the directory atomically, then write `lock.json` with `startedAt`, `runCounter`, `currentChange`, `currentStep`, `currentCheckpoint`, `automationId`, and `heartbeatUpdatedAt`.
- Non-stale existing lock: append progress and stop without changing checkpoint state.
- Stale existing lock: if older than `state.json.lock.staleAfterMinutes`, move it to `recovered-locks/run.lock.<UTC timestamp>`, write `evidence/lock-recovery/<UTC timestamp>.md`, update `state.json.lock.lastRecovery`, then acquire a fresh lock and continue.
- Never silently delete a lock. If stale recovery fails, block with category `stale_lock_recovery_failed`.

## State Machine

Change order:

1. `introduce-study-intake-router`
2. `persist-intake-plan-drafts`
3. `introduce-plan-compiler`
4. `introduce-deadline-scheduler`
5. `redesign-add-initiate-ui`

Each change moves through:

1. `product_deepen_round_1`
2. `product_deepen_round_2`
3. `product_deepen_round_3`
4. `scope_dependency_check`
5. `apply`
6. `completed`

Per heartbeat:

- Product deepening may advance up to three consecutive product-deepen checkpoints for the same change, stopping at round 3.
- `scope_dependency_check` may advance one checkpoint.
- `apply` may advance one independently verifiable task group.
- Do not cross from product-deepen round 3 into `scope_dependency_check` in the same heartbeat.
- Do not advance into the next change until cross-change contract evidence passes.

## Checkpoint Rules

### Product Deepening

For each round:

- Announce and run `opsx-product-deepen`.
- Read the current change proposal, design, specs, and tasks.
- Read adjacent upstream/downstream changes from `crossChangeContracts.changeOrder` when they exist.
- Keep product deepening inside the current change's responsibility boundary; name downstream dependencies without implementing or absorbing them.
- Record explicit scope decisions in the round evidence: in-scope, out-of-scope, deferred upstream dependencies, and downstream contracts preserved.
- Write `openspec/changes/<change>/review-records/product-deepen-round-N.md`.
- Run `openspec validate <change> --strict`.
- Increment `changes[].productDeepenRoundsCompleted` to `N`.
- Append `evidence/manifest.json` and update `progress.md`.

After round 3, set the next checkpoint to `scope_dependency_check`.

### Scope Dependency Check

Complete only when:

- Read the current change proposal, design, specs, and tasks.
- Read adjacent upstream/downstream changes from `crossChangeContracts.changeOrder` when they exist.
- Verify all three product-deepen records contain scope decisions, not only product expansion.
- Verify the current change has not absorbed another change's responsibilities.
- Verify required upstream contracts are already available or explicitly deferred.
- Verify downstream dependencies, enums, payloads, persistence expectations, and UI states are named but not prematurely implemented.
- Write `evidence/scope-dependency/<change>.md`.
- Run `openspec validate <change> --strict`.
- Set `changes[].scopeDependencyCheckCompleted=true`.
- Append a `scope_dependency_check` entry to `evidence/manifest.json` and update `progress.md`.
- Set the next checkpoint to `apply`.

If the check finds scope drift, missing upstream contracts, or a design contradiction, stop with category `scope_drift` or `design_conflict`.

### Apply

Before implementation starts:

- Confirm `changes[].scopeDependencyCheckCompleted=true`.
- Create or verify `evidence/<change>/apply-planning.md`.
- Create or verify `evidence/<change>/apply-task-groups.json` following `evidence/apply-task-groups.schema.md`.
- Set `changes[].applyTaskGroups.status=planned`, set `taskGroupsFile`, and initialize the top-level `applyCursor` for the change.
- Run `openspec validate <change> --strict`.
- Append an `apply_planning` entry to `evidence/manifest.json` and update `progress.md`.
- Create a safe pre-apply checkpoint commit, or block with category `commit_blocked`.
- Evidence format: `evidence/commits/schema.md`.
- Never begin implementation from an ambiguous dirty tree.

For each apply task group:

- Use `openspec-apply-change` or the approved opsx apply skill.
- Follow the fixed chain: OpenSpec apply -> subagent-driven development -> per-task TDD.
- Set `applyCursor.currentGroupId` before editing or testing.
- Write `evidence/<change>/apply-groups/<group-id>.md`.
- Run fresh tests and `openspec validate <change> --strict`.
- Move the group id into `completedGroupIds` only after verification and evidence.
- Prefer one small commit per verified group; if deferred, write commit deferral evidence.

Apply is complete only when all task groups are verified, tasks are complete or explicitly accepted as verification-only, cross-change contract checks pass, `applyCompleted=true`, and the change status is `completed`.

## Recovery And Evidence

- Trust `evidence/manifest.json` before Markdown evidence when checking whether a checkpoint already completed.
- Verify recorded artifact paths and `sha256` hashes when present.
- Never infer apply progress from checked task boxes alone; use `applyCursor`, task-group evidence, and commits.
- Manifest schema: `evidence/manifest.schema.md`.
- Scope/dependency schema: `evidence/scope-dependency/schema.md`.
- Failure schema: `evidence/failures/schema.md`.
- Lock recovery schema: `evidence/lock-recovery/schema.md`.
- Commit schema: `evidence/commits/schema.md`.
- Cross-change schema: `evidence/cross-change-contracts/schema.md`.

If state, manifest, task boxes, and commits disagree, stop and reconcile them in progress/evidence before continuing.

## Git Safety

- Always run `git status --porcelain=v1` after acquiring the lock.
- Never reset, revert, merge, rebase, stash, or use worktrees.
- Classify dirty paths before each checkpoint:
  - `owned_current_checkpoint`: files explicitly created or updated by the current checkpoint evidence.
  - `current_apply_targets`: files listed in the current apply task group `targetFiles`, plus shared test/setup/project files that the group will touch.
  - `protected_unrelated_dirty`: dirty files outside current checkpoint evidence and current apply targets.
  - `blocking_overlap`: dirty files that overlap current apply targets, current checkpoint evidence, required setup/project files, or files that must be staged for the pre-apply checkpoint commit.
- Treat `workspace-baseline.json.expectedPreexistingEntries` as known pre-existing dirt, not automatic permission to edit or stage.
- Dirty paths outside the baseline are not automatically blocking when they are unrelated to the current checkpoint. Record them as `protected_unrelated_dirty`, do not edit or stage them, and continue.
- Block only on `blocking_overlap`, or when the pre-apply checkpoint commit cannot be created with explicit pathspec staging that excludes protected unrelated dirty files.
- Baseline coverage is not permission to overwrite. If a checkpoint needs a baseline path outside its owner policy, block.
- Stage only explicit files listed in checkpoint evidence.
- Never stage broad directories, runtime SQLite/WAL/SHM, DerivedData, logs, screenshots, `.DS_Store`, or `run.lock`.

## Stop Rules

Block only after writing `failure-log.jsonl`, `state.json.lastFailure`, `blockedReason`, and a progress entry.

Immediate stop categories:

- `non_stale_lock_present`
- `stale_lock_recovery_failed`
- `overlapping_user_changes`
- `missing_artifact`
- `openspec_validate_failed` when not fixable in current scope
- `test_failed` after retry budget
- `app_start_failed` after two failures
- `scope_drift`
- `design_conflict`
- `worktree_required`
- `commit_blocked`
- `contract_check_failed`

`currentAttempt` increments for recoverable failures. After `maxRetriesPerCheckpoint`, set `phase=blocked`.

## Cross-Change Contract

After a change's apply is complete and before advancing:

- Read the completed change specs/tasks and the next change proposal/design/specs/tasks.
- Check handoff payloads, persisted entities, enum values, user-facing states, and downstream test expectations.
- Run strict validation for the completed change and the immediate next change.
- Write `evidence/cross-change-contracts/<completed-change>-to-<next-change>.md`.
- Append a `cross_change_contract` manifest entry.
- Update `state.json.crossChangeContracts.lastCheck`.

For the final change, write `redesign-add-initiate-ui-final.md`.

## Done

When all five changes are complete:

1. Set `phase=done`.
2. Write `final-report.md`.
3. Append the final progress entry and manifest entry.
4. Pause automation `add-initiate-changes`.
