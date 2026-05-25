# Apply Group Evidence: session-adapter-and-api-contract

- Automation: add-initiate-changes
- Change: redesign-add-initiate-ui
- Checkpoint: redesign-add-initiate-ui:apply:session-adapter-and-api-contract
- Completed at: 2026-05-25T13:14:55Z
- Result: completed
- Implementation commit: ae36e59c7a84f20d7053808e625e76277296ac63

## Scope

Completed the first Add / Initiate UI apply group covering tasks 0.1, 0.2, 0.3, 0.4, and 1.3.

In scope:

- Backend Add / Initiate session adapter contract.
- Session identity and progress/review state names.
- Role confirmation, anchor confirmation, option-effect, activation, and storage terminal contracts.
- Swift Codable/API-client contract for Add / Initiate calls and payload preservation.
- Legacy URL ingestion compatibility guardrail: Add / Initiate uses adapter endpoints, not the old URL ingest path.

Out of scope:

- Swift ViewModel state machine and UI rendering remain in later apply groups.
- Durable SSE transport remains outside this group; this group adds a lightweight session/progress contract buffer.
- Router heuristics, compiler logic, scheduler math, and activation semantics were not reimplemented.

## TDD Record

RED:

- Added backend tests for missing adapter module/endpoints, session identity, stage names, no active tasks before activation, stale-event rejection, and legacy URL compatibility.
- Added Swift decoding/API-client tests for Add / Initiate request/response models and adapter endpoints.
- Review-driven RED cycles caught and fixed:
  - non-plan start returning a non-canonical `confirm_non_plan_storage` stage;
  - ambiguous route returning `role_review` instead of `needs_input`;
  - stale option effect being confused with activation failure;
  - option effects not persisting a new latest draft version;
  - concurrent/stale option writes without expected-version guard;
  - foreign session mutation/activation;
  - stale activation returning 200 instead of 409.

GREEN:

- Added `assistant_backend/src/study_plan/add_initiate.py` as a thin adapter over existing intake, lifecycle, compiler, scheduler, and activation helpers.
- Added backend routes under `/api/study-intake/add-initiate/*`.
- Added `draftVersion` to plan-generating intake confirmation payloads.
- Added an expected-version guard to `create_meaningful_draft_edit_version`.
- Added Add / Initiate Swift request/response/progress models and API-client/protocol methods.
- Preserved UI payload fields such as clarification questions, existing plan candidates, attachment hints, review packages, and activation results.

REFACTOR:

- Kept option-effect persistence on existing lifecycle versioning rather than adding a new storage model.
- Kept session mismatch and stale-version conflicts as transport conflicts while preserving recoverable activation failures as review states.
- Did not mark OpenSpec task checkboxes; final verification group owns task checkbox completion.

## Review

- Spec compliance review 1: CHANGES_REQUESTED. Fixed non-canonical stages and stale option-effect state.
- Spec compliance review 2: CHANGES_REQUESTED. Fixed option-effect latest-version persistence.
- Spec compliance review 3: APPROVED.
- Code quality review 1: CHANGES_REQUESTED. Fixed expected-version guard, session ownership checks, HTTP 409 mapping, and Swift payload retention.
- Code quality review 2: CHANGES_REQUESTED. Fixed stale activation to raise conflict instead of returning `activation_failed`.
- Final code quality re-review: APPROVED.

## Verification

- `cd assistant_backend && uv run pytest tests/test_study_add_initiate_adapter.py tests/test_study_intake_router.py -k 'add_initiate or session or adapter or progress or legacy'`: 15 passed, 55 deselected.
- `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -only-testing:MalDazeTests/AssistantModelDecodingTests -quiet`: passed.
- `openspec validate redesign-add-initiate-ui --strict`: valid.
- `git diff --check -- assistant_backend/src/study_plan/add_initiate.py assistant_backend/src/routers/study_intake.py assistant_backend/src/study_plan/intake.py assistant_backend/src/study_plan/lifecycle.py assistant_backend/tests/test_study_add_initiate_adapter.py assistant_backend/tests/test_study_intake_router.py MalDaze/LearningAssistant/AssistantAPIClient.swift MalDaze/LearningAssistant/AssistantAPIClientProtocol.swift MalDazeTests/LearningAssistantTests.swift`: no whitespace errors.

## Files

- `assistant_backend/src/study_plan/add_initiate.py`
- `assistant_backend/src/routers/study_intake.py`
- `assistant_backend/src/study_plan/intake.py`
- `assistant_backend/src/study_plan/lifecycle.py`
- `assistant_backend/tests/test_study_add_initiate_adapter.py`
- `assistant_backend/tests/test_study_intake_router.py`
- `MalDaze/LearningAssistant/AssistantAPIClient.swift`
- `MalDaze/LearningAssistant/AssistantAPIClientProtocol.swift`
- `MalDazeTests/LearningAssistantTests.swift`

## Protected Unrelated Dirty Paths

The following dirty paths were present before this checkpoint and were not edited or staged by this apply group:

- `docs/agent-workflow.md`
- `openspec/changes/harden-add-initiate-automation-control/design.md`
- `openspec/changes/harden-add-initiate-automation-control/proposal.md`
- `openspec/changes/harden-add-initiate-automation-control/tasks.md`
- `openspec/changes/redesign-study-intake-planning/iteration-records/round-16-split-readiness-review.md`
- `openspec/changes/redesign-study-intake-planning/pre-split-readiness-audit.md`
- `openspec/changes/redesign-study-intake-planning/split-decision.md`
- `openspec/changes/redesign-study-intake-planning/tasks.md`

## Next

Next checkpoint: redesign-add-initiate-ui:apply:entry-role-and-attachment-review
