# Apply Group Evidence: routing-contracts-and-confirmation

- Automation: add-initiate-changes
- Change: introduce-study-intake-router
- Checkpoint: introduce-study-intake-router:apply:routing-contracts-and-confirmation
- Completed at: 2026-05-25T05:56:51Z
- Functional commit: 5955c594c1da37fc090d185d0f5e20771b2af429

## Scope

Completed tasks:

- 1.2 Implement role recommendation for `new_plan`, `attach_to_existing_plan`, `reference_material`, `later_resource`, and `immediate_one_off`.
- 1.3 Implement router confidence levels and reason strings.
- 1.4 Implement one-question clarification for low-confidence routing.
- 1.5 Implement existing-plan attachment mode handling: `material_only`, `draft_phase`, and `scheduled_work`.
- 1.6 Implement route result contracts with next actions: `role_review`, `answer_routing_question`, `confirm_non_plan_storage`, `select_attachment_target`, and `handoff_to_anchor_review`.
- 1.7 Keep intake machine role separate from canonical source/repo role in route and confirmation payloads.
- 4.1 Add router tests for all supported first-version input types.
- 4.2 Add role tests for new plan, existing-plan attachment, reference, later, and one-off outcomes.
- 4.3 Add one-question clarification tests for ambiguous role cases.
- 4.7 Add existing-plan target-selection tests proving scheduled-work handoff requires target plan and attachment mode confirmation.

## TDD Evidence

Initial RED worker result:

- Command: `cd assistant_backend && uv run pytest tests/test_study_intake_router.py -k 'route or role or clarification or target or contract or input_type'`
- Expected failure: 17 failures because `route_intake_submission`, `confirm_intake_route`, and `/api/study-intake/route` did not exist yet.

Initial GREEN worker result:

- Command: `cd assistant_backend && uv run pytest tests/test_study_intake_router.py -k 'route or role or clarification or target or contract or input_type'`
- Result: 34 passed, 2 warnings.
- Command: `cd assistant_backend && uv run pytest tests/test_study_intake_router.py`
- Result: 34 passed, 2 warnings.

Review-driven fixes:

- Existing-plan target selection and stored route replay:
  - RED command: `cd assistant_backend && uv run pytest tests/test_study_intake_router.py -k 'existingPlanId or selected_target or route'`
  - Expected failure: helper did not accept `existing_plan_id`; API did not pass `existingPlanId`; retry responses could be rebuilt from retry body/current candidates.
  - GREEN command: `cd assistant_backend && uv run pytest tests/test_study_intake_router.py -k 'idempotency or existingPlanId or target or route' && uv run pytest tests/test_study_intake_router.py`
  - Result: focused set 37 passed; full file 37 passed.
- Stored optional routing metadata:
  - RED command: `cd assistant_backend && uv run pytest tests/test_study_intake_router.py -k 'retry or idempotency or attachment_mode'`
  - Expected failure: retry lost first-route `canonicalRepoRole` and `attachmentModeSuggestion`.
  - GREEN command: `cd assistant_backend && uv run pytest tests/test_study_intake_router.py -k 'retry or idempotency or attachment_mode'`
  - Result: 5 passed; full file 39 passed, 2 warnings.
- Invalid target, practice wording, and lost-race replay:
  - RED command: `cd assistant_backend && uv run pytest tests/test_study_intake_router.py -k 'invalid_target or planning_beats_practice or idempotency or route'`
  - Expected failure: invalid attach targets were accepted; `practice` language over-triggered one-off routing; lost-race response used local candidate fields.
  - GREEN command: same focused command.
  - Result: 45 passed; full file 45 passed, 2 warnings.
- Route API ValueError mapping:
  - RED command: `uv run pytest tests/test_study_intake_router.py::test_api_route_invalid_existing_plan_id_returns_400_without_intake_row`
  - Expected failure: stale archived `existingPlanId` surfaced as unhandled `ValueError`.
  - GREEN result: focused test 1 passed; full file 46 passed, 2 warnings.
- Non-attach `existingPlanId` validation:
  - RED command: `uv run pytest tests/test_study_intake_router.py::test_route_rejects_invalid_existing_plan_id_before_creating_non_attach_item tests/test_study_intake_router.py::test_api_route_invalid_existing_plan_id_for_non_attach_returns_400_without_intake_row`
  - Expected failure: helper did not raise for four non-attach role cases and API returned 200 instead of 400.
  - GREEN result: focused tests 5 passed; full file 51 passed, 2 warnings.

## Implementation Summary

- Registered the `study_intake` FastAPI router under `/api`.
- Added `POST /api/study-intake/route` and `POST /api/study-intake/confirm`.
- Added deterministic first-version role recommendation for new plan, existing-plan attachment, reference, later resource, and immediate one-off routing.
- Added confidence, public reason codes, one-question clarification, route payload next actions, and `createsActiveTasks=false` guarantees.
- Added existing-plan candidate selection for active `study_project` resources only.
- Validated any new request `existingPlanId` before creating an intake item, across attach and non-attach route outcomes.
- Preserved idempotent stored-item replay before validating retry-body fields so duplicate client request ids are stable and not polluted by retry body or current candidates.
- Persisted internal route metadata in reason codes for selected plan, candidate plans, canonical repo role, and attachment mode, while filtering internal codes from public `reasonCodes`.
- Kept `canonicalRepoRole` separate from intake `recommendedRole`.
- For `material_only`, persisted a plan attachment without altering schedule.
- For `draft_phase`, `scheduled_work`, and `new_plan`, returned `handoff_to_anchor_review` / `awaiting_anchor_review` without implementing draft persistence, plan compilation, scheduling, or UI.

## Review

Spec compliance and code quality review:

- Initial result: CHANGES_REQUIRED.
- Issues: stale invalid `existingPlanId` was mapped to 500; attach-only target validation did not cover non-attach route outcomes.
- Fixes: route endpoint now maps helper `ValueError` to 400; new requests validate any provided `existingPlanId` before intake creation; stored-item replay remains first for idempotent retries.
- Final result: APPROVED.
- Residual non-blocking note: `attach_material_to_plan` assumes callers validate target plans; production confirmation path performs that validation before calling it.

## Verification

- `cd assistant_backend && uv run pytest tests/test_study_intake_router.py`: 51 passed, 2 warnings.
- `cd assistant_backend && uv run pytest tests/test_study_plan_router.py tests/test_study_views_today.py`: 12 passed, 2 warnings.
- `cd assistant_backend && uv run pytest tests/test_integration.py -q`: 16 passed, 2 warnings.
- `openspec validate introduce-study-intake-router --strict`: valid.
- `openspec instructions apply --change introduce-study-intake-router --json`: 21/21 tasks complete.

## Scope Boundary

This group did not implement:

- Draft plan persistence.
- Plan Compiler / daily plan generation.
- Deadline Scheduler.
- Add / Initiate UI surfaces.
- Explicit scheduling for `immediate_one_off` items.

These remain assigned to downstream child changes.

## Protected Unrelated Dirty Paths

The following paths were protected and not edited or staged by this checkpoint:

- `docs/agent-workflow.md`
- `openspec/changes/harden-add-initiate-automation-control/design.md`
- `openspec/changes/harden-add-initiate-automation-control/proposal.md`
- `openspec/changes/harden-add-initiate-automation-control/tasks.md`
- `openspec/changes/redesign-study-intake-planning/iteration-records/round-16-split-readiness-review.md`
- `openspec/changes/redesign-study-intake-planning/pre-split-readiness-audit.md`
- `openspec/changes/redesign-study-intake-planning/split-decision.md`
- `openspec/changes/redesign-study-intake-planning/tasks.md`

## Next Checkpoint

introduce-study-intake-router:apply:cross-change-contract-to-persist-intake-plan-drafts
