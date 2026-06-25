# Apply Group Evidence: fallback-progress-and-final-verification

- Automation: add-initiate-changes
- Change: persist-intake-plan-drafts
- Checkpoint: persist-intake-plan-drafts:apply:fallback-progress-and-final-verification
- Timestamp: 2026-05-25T08:26:11Z
- Result: completed
- Implementation commit: 2e1ef56eedbf1bf40cccc79fdb09aea0c35dd28f

## Scope

Completed OpenSpec tasks:

- 3.1 Persist low-energy fallback completion separately from full task completion.
- 3.2 Mark fallback-only completion as `needs_followup`.
- 3.3 Ensure fallback-only completion never sets full `completed_at` unless the full task is separately completed.
- 4.9 Add fallback completion tests proving fallback progress does not mark the full task complete.

## TDD Trace

The implementation worker used TDD with RED/GREEN cycles.

Initial RED:

- `cd assistant_backend && uv run pytest tests/test_study_views_completion.py -k fallback`
- Result: failed as expected. The new fallback completion route was missing and the legacy DB migration test showed missing fallback-progress columns.

Review-fix RED:

- `cd assistant_backend && uv run pytest tests/test_study_views_completion.py -k fallback`
- Result: 2 failed, 3 passed. Expected failures proved stale `needs_followup=1` after full completion and invalid follow-up marking when fallback was called after full completion.

Final GREEN:

- `cd assistant_backend && uv run pytest tests/test_study_views_completion.py -k 'fallback or completion'`
- Result: 11 passed, 2 third-party warnings.

## Implementation Summary

- Added fallback-progress columns to active `tasks`: `fallback_completed_at`, `fallback_actual_minutes`, and `needs_followup`.
- Added idempotent startup migration for those columns on existing databases.
- Added `complete_task_fallback()` for fallback-only completion without setting full `completed_at` or full `actual_minutes`.
- Added `POST /api/tasks/{task_id}/fallback-complete`.
- Kept fallback-only progress out of unit/resource completion counts and full completion events.
- Cleared `needs_followup` when a task is later fully completed.
- Made fallback completion a no-op for already fully completed tasks.
- Added tests for fallback-only progress, fallback-to-full transition, full-then-fallback no-op behavior, repeated fallback idempotency, and legacy fallback column migration.

Out of scope:

- No compiler, scheduler, UI, smart-mode, or active-plan adjustment behavior was added.
- Positive-minute request validation remains deferred because the existing full completion endpoint accepts the same request shape and this group stayed inside fallback persistence semantics.

## Verification

- `cd assistant_backend && uv run pytest tests/test_study_plan_lifecycle.py -k 'fallback'`: 1 passed, 42 deselected.
- `cd assistant_backend && uv run pytest tests/test_study_views_completion.py -k 'fallback or completion'`: 11 passed, 2 third-party warnings.
- `cd assistant_backend && uv run pytest tests/test_study_plan_lifecycle.py tests/test_study_plan_router.py tests/test_study_intake_router.py tests/test_study_views_today.py tests/test_integration.py`: 131 passed, 2 third-party warnings.
- `openspec validate persist-intake-plan-drafts --strict`: valid.
- `openspec instructions apply --change persist-intake-plan-drafts --json`: 35/35 tasks complete, state `all_done`.
- `git diff --check -- assistant_backend/src/db/schema.py assistant_backend/src/db/init.py assistant_backend/src/db/queries.py assistant_backend/src/routers/tasks.py assistant_backend/tests/test_study_views_completion.py assistant_backend/tests/test_study_plan_lifecycle.py openspec/changes/persist-intake-plan-drafts/tasks.md`: no whitespace errors.

## Reviews

Spec compliance review:

- Initial result: changes required.
- Required fixes: `needs_followup` was incorrectly left true after full completion and could be added after full completion.

Code quality review:

- Initial result: changes required.
- Required fixes: full/fallback API transitions could create stale or misleading follow-up state.
- P2 deferred: positive-minute validation for `actual_minutes`, because the existing full completion endpoint has the same request model and changing it here would broaden this persistence group.

Final re-review:

- Result: approved.
- Remaining P0/P1/P2 findings: none.

## Protected Unrelated Dirty Paths

These paths were present before the checkpoint or unrelated to this apply group and were not staged:

- `docs/agent-workflow.md`
- `openspec/changes/harden-add-initiate-automation-control/design.md`
- `openspec/changes/harden-add-initiate-automation-control/proposal.md`
- `openspec/changes/harden-add-initiate-automation-control/tasks.md`
- `openspec/changes/redesign-study-intake-planning/iteration-records/round-16-split-readiness-review.md`
- `openspec/changes/redesign-study-intake-planning/pre-split-readiness-audit.md`
- `openspec/changes/redesign-study-intake-planning/split-decision.md`
- `openspec/changes/redesign-study-intake-planning/tasks.md`

## Files Changed

- `assistant_backend/src/db/schema.py`
- `assistant_backend/src/db/init.py`
- `assistant_backend/src/db/queries.py`
- `assistant_backend/src/routers/tasks.py`
- `assistant_backend/tests/test_study_views_completion.py`
- `assistant_backend/tests/test_study_plan_lifecycle.py`
- `openspec/changes/persist-intake-plan-drafts/tasks.md`
