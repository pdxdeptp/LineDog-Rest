# Apply Group Evidence: noise-boundaries-and-active-refresh

- Automation: add-initiate-changes
- Run counter: 41
- Change: redesign-add-initiate-ui
- Checkpoint: redesign-add-initiate-ui:apply:noise-boundaries-and-active-refresh
- Completed at: 2026-05-25T17:13:27Z
- Result: completed

## Scope

Tasks covered: 4.1, 4.2, 4.3, 4.4, 4.5.

This group verifies and implements the Add / Initiate no-noise boundary:

- Unconfirmed `draft_review` plans do not appear in Today or active Calendar until activation.
- `stored_non_plan`, later/reference resources, and `material_only` attachments do not create Today badges, deadline risk, smart-mode proposals, reminders, or active tasks.
- Processing, option-effect, cancel, activation-failure, and terminal storage/material states are rendered as quiet Add / Initiate states, not as created tasks.
- Activation success is the only path that refreshes Home resources, Today, project overview, active Calendar facts, and smart proposal context.

## TDD And Implementation Notes

Backend work was verification-only because the existing backend behavior already satisfied the no-noise boundary. The backend worker added tests before making any backend source changes; the tests passed without production edits, so no backend implementation code was written.

Swift work followed RED/GREEN:

- RED: `testAddInitiateActivationSuccessRefreshesActiveSurfacesAndSmartProposalContext` failed before the ViewModel refreshed active surfaces after a successful activation.
- GREEN: `activateAddInitiateDraft()` now captures the previous smart-mode red state and refreshes active surfaces only when the accepted response is `reviewState == .activated && createsActiveTasks`.
- RED after review: `testActivationResponseAfterEditingDraftDoesNotOverwriteAnchorReviewOrRefreshActiveSurfaces` and `testActivationThrownErrorAfterEditingDraftDoesNotOverwriteAnchorReviewOrRefreshActiveSurfaces` covered stale success/error responses after the user edits while activation is in flight.
- GREEN after review: activation success and thrown-error paths now require the active local flow to still be `.activationProgress` and the activation request sequence to match before mutating local state.

## Reviews

- Spec compliance review: APPROVED. The implementation satisfies tasks 4.1-4.5 and keeps non-active Add / Initiate states out of active surfaces.
- Code quality review 1: CHANGES_REQUESTED. It found a P1 stale activation thrown-error path that could clear `.anchorReview` and show activation failure/offline state after the user continued editing.
- Code quality review 2: APPROVED. The stale activation success/error paths are both guarded, active refresh is limited to activated task-creating responses, and no new Critical or Important issues were found.

## Verification

- `cd assistant_backend && uv run pytest tests/test_study_add_initiate_adapter.py tests/test_study_views_today.py tests/test_study_views_calendar.py tests/test_study_smart_mode_proposals.py -k 'add_initiate or draft or non_plan or material or smart or today or calendar'`
  - Result: 46 passed, 2 warnings.
- `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -parallel-testing-enabled NO -only-testing:MalDazeTests/LearningAssistantViewModelTests -only-testing:MalDazeTests/LearningAssistantUISourceTests -quiet`
  - Result: passed, exit 0.
- `openspec validate redesign-add-initiate-ui --strict`
  - Result: valid.
- `git diff --check -- assistant_backend/tests/test_study_add_initiate_adapter.py assistant_backend/tests/test_study_views_today.py assistant_backend/tests/test_study_views_calendar.py assistant_backend/tests/test_study_smart_mode_proposals.py MalDaze/LearningAssistant/LearningAssistantViewModel.swift MalDaze/LearningAssistant/AssistantPanelView.swift MalDazeTests/LearningAssistantTests.swift`
  - Result: clean.

An earlier focused Swift suite run reported a failure in `testFetchStudyCalendarLoadKeepsLatestRangeWhenOlderRequestFinishesLast`. The targeted test passed on immediate rerun, and the full focused suite passed on subsequent fresh runs before and after the stale-error fix, so it was treated as a non-reproducible timing fluctuation rather than a blocker for this group.

## Changed Files

- `assistant_backend/tests/test_study_views_today.py`
  - sha256: `a5b389dac93818d28e5b759228c887e58d4d3fba8b90f522d17d102f49f0de21`
- `assistant_backend/tests/test_study_views_calendar.py`
  - sha256: `2384b6f03afc796dec402626d4087522703c470e81c9eb13475ef011f2a74721`
- `assistant_backend/tests/test_study_smart_mode_proposals.py`
  - sha256: `a195d1544698df918daac71432d937250651ea4b5a599cfcfeccd49c3a734a49`
- `MalDaze/LearningAssistant/LearningAssistantViewModel.swift`
  - sha256: `a41e692ca76ee9933dfbf3410fcd011df6e2916f8dc34abe55d91284ccf411ab`
- `MalDazeTests/LearningAssistantTests.swift`
  - sha256: `4303b05b1a2ac8713772c471ae17e2c0dc65651ff0f3f594ea44e38816e68cef`

## Next Checkpoint

redesign-add-initiate-ui:apply:real-context-qa-and-final-verification
