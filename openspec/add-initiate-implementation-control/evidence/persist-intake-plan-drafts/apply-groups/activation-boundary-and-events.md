# Apply Group Evidence: activation-boundary-and-events

- Automation: add-initiate-changes
- Change: persist-intake-plan-drafts
- Checkpoint: persist-intake-plan-drafts:apply:activation-boundary-and-events
- Timestamp: 2026-05-25T07:46:40Z
- Result: completed
- Implementation commit: ab1587b60b1fed5c13c9185f7473ebdb52a371eb

## Scope

Completed OpenSpec tasks:

- 2.1 activation event recording
- 2.2 stale activation rejection
- 2.3 activation-ready task and schedule guard
- 2.4 transactional activation rollback
- 2.5 discard/cancel active-state separation
- 2.6 invalid lifecycle transition rejection
- 2.7 existing-plan target activation
- 2.8 duplicate activation idempotency safety
- 2.9 discard-after-activation rejection
- 4.4 stale activation tests
- 4.5 activation event and rollback tests
- 4.6 activation-ready rejection tests
- 4.7 invalid lifecycle transition tests
- 4.12 duplicate activation tests
- 4.13 discard-after-activation tests

Task 4.11 was already completed by the previous apply group for draft kind and target-plan storage linkage; this group added the activation behavior that consumes that target linkage.

## TDD Trace

The implementation worker used TDD with RED/GREEN cycles.

Initial RED:

- `cd assistant_backend && uv run pytest tests/test_study_plan_lifecycle.py -k 'confirm or activation or stale or transaction or duplicate or discard or transition or target_plan'`
- Result: 8 failed, 8 passed, 17 deselected.
- Expected failures covered legacy confirmed/cancelled state assumptions, missing draft-version activation input, and missing package activation support.

Second RED after spec review:

- Lifecycle focused command failed because missing `schedule_version` package activation succeeded instead of rejecting.
- Router focused command failed because stale `{"draft_version": 1}` returned 200 instead of 409.

Third RED after latest-activatable review:

- Lifecycle focused command failed with expected failures for v1 `draft_review` blocked by newer `needs_input`/`compile_failed`, `infeasible_review` activation rejection, and invalid lifecycle transitions being allowed.
- Router focused command failed because explicit `{"draft_version": 1}` was rejected before lifecycle validation when header status had moved to a newer non-activatable package.

## Implementation Summary

- Added package activation from persisted `draft_review` and activation-ready `infeasible_review` packages.
- Activation now validates task data, schedule slices, and generated schedule version before creating active rows.
- Activation now records an immutable `study_project_activated` event with intake id, activated draft version, assumptions, schedule version, created active task ids, draft kind, resource id, and target plan id.
- Stale activation checks use the highest activatable package version instead of the header latest version, so newer `needs_input` or `compile_failed` package versions do not incorrectly stale the previous activation-ready package.
- Existing-plan draft activation appends units/tasks under the recorded target active plan without creating a new top-level resource.
- Duplicate activation and discard-after-activation are non-destructive.
- Draft package write entrypoints now enforce the V1 lifecycle transition table before status mutation.
- Router confirm now accepts an optional user-observed `draft_version` body while preserving no-body compatibility.

Out of scope:

- No compiler generation, scheduler implementation, UI, smart-mode behavior, or fallback progress implementation was added.

## Verification

- `cd assistant_backend && uv run pytest tests/test_study_plan_lifecycle.py -k 'confirm or activation or stale or transaction or duplicate or discard or transition or target_plan or package'`: 38 passed, 4 deselected.
- `cd assistant_backend && uv run pytest tests/test_study_plan_router.py -k 'confirm_endpoint or cancel_endpoint or stale'`: 7 passed, 5 deselected, 2 third-party warnings.
- `cd assistant_backend && uv run pytest tests/test_study_views_today.py`: 4 passed, 2 third-party warnings.
- `cd assistant_backend && uv run pytest tests/test_study_plan_lifecycle.py tests/test_study_plan_router.py tests/test_study_views_today.py`: 58 passed, 2 third-party warnings.
- `openspec validate persist-intake-plan-drafts --strict`: valid.
- `openspec instructions apply --change persist-intake-plan-drafts --json`: 31/35 tasks complete after task bookkeeping.
- `git diff --check`: passed for implementation and task files.

## Reviews

Spec compliance review:

- Initial result: issues found.
- Required fixes: router stale selection, required schedule version, package-flow invalid transition coverage, and package-flow duplicate activation coverage.
- Second result: issues found.
- Required fixes: latest activatable version semantics and V1 lifecycle transition validation for package write entrypoints.
- Final result: approved; no remaining P0/P1/P2 spec compliance findings.

Code quality review:

- Final result: approved.
- P0/P1 findings: none.
- P2 notes retained for future hardening:
  - package JSON shape errors can surface as non-ValueError exceptions if persisted JSON is malformed;
  - existing-plan `total_units` may remain inconsistent if historical `total_units` was already below actual unit count;
  - package activation event keeps legacy `duration_estimates` empty for package activations;
  - external clients expecting `cancelled` may need compatibility handling because V1 spec uses `discarded`.

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

- `assistant_backend/src/study_plan/lifecycle.py`
- `assistant_backend/src/routers/study_plan.py`
- `assistant_backend/tests/test_study_plan_lifecycle.py`
- `assistant_backend/tests/test_study_plan_router.py`
- `assistant_backend/tests/test_study_views_today.py`
- `openspec/changes/persist-intake-plan-drafts/tasks.md`
