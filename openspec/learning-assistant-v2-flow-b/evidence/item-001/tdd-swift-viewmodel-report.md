# TDD Report: Swift ViewModel Study Plan Draft Flow

## Scope

- OpenSpec change: `introduce-study-plan-foundation`
- Tasks: 4.3 / 4.4
- Files changed:
  - `MalDaze/LearningAssistant/LearningAssistantViewModel.swift`
  - `MalDazeTests/LearningAssistantTests.swift`

## RED Evidence

- Initial ViewModel RED: targeted Swift tests failed because the ViewModel had no study-plan draft flow state or methods for URL intake, clarification submit/skip, duration edit, cancel, and explicit confirm.
- Review-driven RED 1: `testStartStudyPlanFailurePreservesExistingDraftFlowAndResetsLoading` failed because start failure cleared an existing review draft.
- Review-driven RED 2: `testConfirmStudyPlanDraftIgnoresDuplicateSubmitWhileInFlight` failed because duplicate confirm could send multiple confirm/refresh requests.
- Review-driven RED 3: pre-review confirm/edit tests failed because confirm and duration edit only required `draftId`, not a generated review draft.
- Review-driven RED 4: confirm-in-flight cross-action tests failed because start/cancel could interleave with confirm and create silent activation/stale state.
- Review-driven RED 5: test helper compile failed on `waitForStudyPlanConfirmToStart` and then on `recordStudyPlanConfirmStartedForWaiterTest`, driving deterministic in-flight test gates.

## GREEN Evidence

- Implemented study-plan ViewModel state:
  - `studyPlanDraftId`
  - `studyPlanClarification`
  - `studyPlanDraft`
  - `studyPlanError`
  - study-plan loading flags and a unified busy guard.
- Implemented ViewModel actions:
  - `startStudyPlan`
  - `submitStudyPlanClarification`
  - `skipStudyPlanClarification`
  - `updateStudyPlanDraftTaskDuration`
  - `cancelStudyPlanDraft`
  - `confirmStudyPlanDraft`
- Added review-ready guard so edit/confirm require a local draft whose id matches the current draft id and whose status is `review`.
- Added cross-action busy guard so start/submit/update/cancel/confirm cannot interleave while another study-plan draft mutation is in flight.
- Replaced `Task.yield()`-based in-flight tests with a deterministic `NSLock`-protected continuation gate.

## Review Results

- Spec compliance review: APPROVED.
- Code quality review initially requested fixes for:
  - start failure preserving existing draft state,
  - duplicate/cross-action confirm re-entry,
  - review-ready boundaries before edit/confirm,
  - flaky `Task.yield()` in-flight tests,
  - non-atomic continuation gate.
- Final code quality review: APPROVED.

## Verification

- `openspec validate introduce-study-plan-foundation --strict`: PASS.
- `cd assistant_backend && .venv/bin/python -m pytest tests/test_study_plan_router.py tests/test_study_plan_decomposition.py tests/test_study_plan_clarification.py tests/test_study_plan_scheduling.py tests/test_study_plan_lifecycle.py -q`: `27 passed, 2 warnings`.
- `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -destination 'platform=macOS' -only-testing:MalDazeTests/LearningAssistantViewModelTests -only-testing:MalDazeTests/AssistantModelDecodingTests`: `** TEST SUCCEEDED **`
- `git diff --check`: PASS.

## Residual Risks

- Existing Swift concurrency warnings remain outside this task scope.
- UI wiring and manual app verification are intentionally deferred to tasks 5.1 through 5.4.
