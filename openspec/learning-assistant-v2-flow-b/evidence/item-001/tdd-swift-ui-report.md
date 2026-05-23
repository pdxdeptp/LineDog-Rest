# TDD Evidence: Swift Study Plan Intake And Review UI

## Scope

- OpenSpec change: `introduce-study-plan-foundation`
- Tasks: 5.1, 5.2, 5.3
- Files changed by the UI task:
  - `MalDaze/LearningAssistant/AssistantPanelView.swift`
  - `MalDazeTests/LearningAssistantTests.swift`

## RED

- Initial presentation tests were added before UI implementation.
- RED command:
  - `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -destination 'platform=macOS' -only-testing:MalDazeTests/LearningAssistantUISourceTests`
- Expected RED result:
  - `testAssistantPanelAddResourceUsesStudyPlanIntakeView`
  - `testStudyPlanIntakeReviewUIWiresDraftFlowControls`
- Failure reason:
  - `StudyPlanIntakeView`, guided clarification card, draft review controls, and study-plan ViewModel call wiring did not exist yet.

## GREEN

- Implemented `StudyPlanIntakeView` inside `AssistantPanelView.swift` and routed `.addResource` to the v2 study-plan intake flow.
- Added minimal UI for:
  - URL intake.
  - Required deadline field with a usable default date.
  - Daily capacity selection passed into `startStudyPlan`.
  - Bounded guided clarification card with recommended/default answers.
  - Skip path for rough plan generation.
  - Review-state draft facts, low-calibration marker, over-capacity marker, expected-late marker.
  - Duration edit, cancel, and explicit confirm controls.
- Review-driven fixes:
  - Reset clarification answers across draft identities.
  - Rebuild local draft duration state when the server returns changed task estimates for the same draft.
  - Remove the hidden `hasSelectedDeadline` gate so the visible default deadline can be submitted.
  - Strengthen source-level UI tests so removing the duration identity reset would fail tests.

## Reviews

- Spec compliance review: APPROVED.
- Code quality review: initially CHANGES_REQUESTED for cross-draft local-state pollution and the hidden deadline gate.
- Code quality re-review after fixes: CHANGES_REQUESTED because tests did not lock the duration identity reset tightly enough.
- Final code quality re-review: APPROVED.

## Verification

- `openspec validate introduce-study-plan-foundation --strict`: PASS.
- Backend:
  - `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_plan_router.py tests/test_study_plan_decomposition.py tests/test_study_plan_clarification.py tests/test_study_plan_scheduling.py tests/test_study_plan_lifecycle.py -q`
  - Result: `27 passed, 2 warnings`.
- Swift:
  - `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -destination 'platform=macOS' -only-testing:MalDazeTests/LearningAssistantUISourceTests -only-testing:MalDazeTests/LearningAssistantViewModelTests -only-testing:MalDazeTests/AssistantModelDecodingTests`
  - Result: `** TEST SUCCEEDED **`.
- Whitespace:
  - `git diff --check`: PASS.

## App-Verification Regression Fix

- During task 5.4 Computer Use verification, the clarified-answer radio buttons exposed a real UI regression: multiple options sharing the same backend answer value appeared selected at the same time.
- RED: added `testStudyPlanClarificationRadioOptionsUseUniqueOptionIdTagsAndSubmitAnswerValues`, which fails if the Picker tags use `option.value`.
- GREEN: changed the radio UI selection key to `option.id`, added a mapper back to the submitted answer value, and reset option selections across draft identities.
- Re-review:
  - Spec compliance review: APPROVED.
  - Code quality review: APPROVED, with a non-blocking note that custom-text entry still shows a default radio fallback visually while submitting the custom answer.
- Verification:
  - `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -destination 'platform=macOS' -only-testing:MalDazeTests/LearningAssistantUISourceTests -only-testing:MalDazeTests/LearningAssistantViewModelTests -only-testing:MalDazeTests/AssistantModelDecodingTests`
  - Result: `** TEST SUCCEEDED **`.
  - Rebuilt and relaunched the current checkout app, then reverified single-selected radio behavior through Computer Use.

## Remaining Risk

- `screencapture` failed in this environment, so task 5.4 uses Computer Use accessibility-tree evidence and backend/API checks instead of screenshots.
