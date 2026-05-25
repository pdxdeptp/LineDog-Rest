## Context

The Add / Initiate automation is a heartbeat automation that continues work in `/Users/cpt/Public/MalDaze` by reading local control files. The automation prompt has been updated to require three product-deepen rounds, but the local source of truth still records two rounds and the current checkpoint has already advanced to `apply_readiness`. The same control files also represent `apply` as one coarse checkpoint even though each change contains many independently verifiable tasks.

## Goals / Non-Goals

**Goals:**

- Make `state.json`, `runbook.md`, `progress.md`, and the heartbeat prompt agree on three product-deepen rounds.
- Preserve a clear audit trail for the two-round to three-round migration.
- Represent apply progress at task-group granularity with enough evidence to resume safely.
- Establish a workspace safety baseline that prevents unrelated or newly overlapping worktree changes from being staged or overwritten.

**Non-Goals:**

- Implement any product feature from the Add / Initiate changes.
- Clean up, archive, reset, or commit unrelated user changes.
- Replace the existing lock strategy or move the automation to a worktree.

## Decisions

1. Treat `state.json` as the durable state-machine source of truth and migrate it in place.
   - The migration updates `requiredProductDeepenRounds` to 3, moves the current checkpoint back to `product_deepen_round_3` when only two rounds are complete, and records migration metadata.
   - Alternative considered: rely on the heartbeat prompt override. That keeps the contradiction alive and is unsafe for long runs.

2. Record the migration in both machine-readable and human-readable evidence.
   - A new migration evidence file captures previous state, new state, reason, and verification commands.
   - `progress.md` records the migration as a run log entry and updates the current status summary.

3. Track apply task groups in `state.json`.
   - Each change gets an `applyTaskGroups` list with ids, task ranges, status, evidence path, test command, validation command, commit hash field, and blocking reason field.
   - The active apply group is represented by `currentApplyTaskGroupId` when `currentStep` is `apply`.

4. Add a workspace safety baseline instead of trying to clean the worktree.
   - The baseline records accepted pre-existing paths and owned automation paths.
   - The runbook requires each run to compare fresh `git status --short` output against the baseline and block only on unsafe new or overlapping paths.

## Risks / Trade-offs

- Migration can look like a backward step from `apply_readiness` to `product_deepen_round_3` -> mitigated by explicit migration evidence.
- Apply task groups may need adjustment as implementation reveals better boundaries -> mitigated by allowing task-group definitions to be updated before an apply group starts.
- Workspace baseline can become stale -> mitigated by recording when it was captured and requiring a fresh comparison on every run.
