# Policy Update: Dirty Workspace Classification

## Timestamp

2026-05-25T04:38:40Z

## Reason

The previous git-safety rule blocked apply when it found any dirty path outside `workspace-baseline.json`. That was too broad for this automation because unrelated user edits can coexist safely with a path-scoped apply run.

The observed case was `docs/agent-workflow.md`, which is unrelated to the current apply group `intake-data-and-idempotency`.

## New Rule

After `git status --porcelain=v1`, classify dirty paths into:

- `owned_current_checkpoint`: files explicitly created or updated by the current checkpoint evidence.
- `current_apply_targets`: files listed in the current apply task group `targetFiles`, plus shared test/setup/project files that the group will touch.
- `protected_unrelated_dirty`: dirty files outside the current apply targets and outside current checkpoint evidence.
- `blocking_overlap`: dirty files that overlap current apply targets, current checkpoint evidence, required setup/project files, or files that must be staged for the pre-apply checkpoint commit.

Only `blocking_overlap` blocks apply. `protected_unrelated_dirty` is recorded and must not be edited, staged, or used to satisfy tests.

## Pre-Apply Commit Rule

The pre-apply checkpoint commit must use explicit pathspec staging for current automation/change/evidence files. It must not stage protected unrelated dirty files.

If a safe pathspec commit cannot be created without including unrelated dirty work, block with `commit_blocked`.

## Current Reclassification

- `docs/agent-workflow.md`: `protected_unrelated_dirty`

It does not overlap the first apply group targets:

- `assistant_backend/src/db/schema.py`
- `assistant_backend/src/db/queries.py`
- `assistant_backend/src/study_plan/intake.py`
- `assistant_backend/tests/test_study_intake_router.py`

## Result

The previous `overlapping_user_changes` block is considered overly conservative. The automation may resume from `introduce-study-intake-router:apply:intake-data-and-idempotency` while protecting `docs/agent-workflow.md`.
