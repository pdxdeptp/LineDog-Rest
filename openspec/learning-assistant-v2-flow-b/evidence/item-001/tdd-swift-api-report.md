# ITEM-001 TDD Swift API Report

## Scope

- OpenSpec change: `introduce-study-plan-foundation`
- Tasks: 4.1, 4.2
- Spec area: Swift study-plan draft-flow API models and client methods
- Worker: `019e558a-e7b6-7720-9566-0b97ae61ddee`

## RED Evidence

### Initial RED

- Command: `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -only-testing:MalDazeTests/AssistantModelDecodingTests -only-testing:MalDazeTests/LearningAssistantViewModelTests -destination 'platform=macOS'`
- Result: expected compile failures.
- Failure reason: missing study-plan models and protocol/client methods.

### Start Response RED

- Spec review found that `startStudyPlan(...) -> StudyPlanClarification` could not drive later draft operations because it did not expose `draftId`.
- Added RED test for `StudyPlanStartResponse { draft_id, clarification }` and for using `start.draftId` in the protocol/mock draft-flow test.
- Failure reason: `StudyPlanStartResponse` and mock start result were missing.

## GREEN Evidence

- Command: `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -destination 'platform=macOS' -only-testing:MalDazeTests/AssistantModelDecodingTests -only-testing:MalDazeTests/LearningAssistantViewModelTests`
- Result: `** TEST SUCCEEDED **`
- OpenSpec validation: `openspec validate introduce-study-plan-foundation --strict` passed.

## Implementation Summary

- Added Swift models for:
  - `StudyPlanStartResponse`;
  - `StudyPlanClarification`;
  - `StudyPlanClarificationQuestion`;
  - `StudyPlanClarificationOption`;
  - `StudyPlanSkipAction`;
  - `StudyPlanSkipClarificationResponse`;
  - `StudyPlanDraft`;
  - `StudyPlanDraftTask`;
  - `StudyPlanOverCapacityDay`;
  - `StudyPlanActivationResult`;
  - study-plan request bodies.
- Added `AssistantAPIClientProtocol` and `AssistantAPIClient` methods for:
  - start URL study-plan intake;
  - submit clarification/skip response;
  - update draft task duration;
  - cancel draft;
  - confirm draft.
- Updated test mock and preview fixture API client to compile with the new protocol.
- Backend router tasks 3.5/3.6 were added and completed after code quality review found the Swift client was pointing at dead endpoints.

## Reviews

### Spec Compliance

- First review: `CHANGES_REQUIRED`.
- Blocking issue: `startStudyPlan` did not return a follow-up identifier.
- Re-review after `StudyPlanStartResponse`: `APPROVED`.

### Code Quality

- First review: `CHANGES_REQUIRED`.
- Blocking issue: Swift client pointed to unregistered backend routes.
- Backend router was implemented and reviewed to resolve the blocker.
- Remaining follow-ups:
  - add safer URL decoding for study-plan source URLs before UI opens them;
  - consider request tests with injectable session/baseURL;
  - clarify whether `StudyPlanSkipClarificationResponse` remains a public REST boundary model.

## Status

Tasks 4.1 and 4.2 are complete.
