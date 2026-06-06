# Progress

## 2026-05-31

- Implemented Add / Initiate draft review hardening in the desktop assistant panel:
  task title editing is no longer presented as a saved draft edit, estimate edits are applied through `edit_estimates`, and local pending estimate edits block activation until applied.
- Added visible option parameter confirmations for extend deadline, increase capacity, lower depth, rebalance, and estimate edits.
- Added local validation so required option parameters are not sent empty; missing deadline, capacity, depth, or estimate edits show guidance before any option-effect API call.
- Kept hard-deadline drafts from showing `accept_late_finish`, preserved compact-first draft review, and kept full schedule/source details behind explicit expansion controls.
- Added progress-state handling so estimate updates from draft review show draft-update progress copy rather than infeasible-review copy, and per-task estimate controls are disabled while an option effect is in flight.
- Review status:
  - Spec compliance review initially found missing-parameter gaps; fixed and passed re-review.
  - Code-quality review found misleading activation guidance and in-flight edit controls; fixed and passed final re-review.
- Verification passed:
  - `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -parallel-testing-enabled NO -only-testing:MalDazeTests/LearningAssistantUISourceTests -only-testing:MalDazeTests/LearningAssistantViewModelTests -quiet`
  - `cd assistant_backend && uv run pytest tests/test_study_add_initiate_adapter.py tests/test_study_intake_router.py -q`
  - `openspec validate harden-add-initiate-draft-review --strict`
  - `git diff --check -- MalDaze/LearningAssistant/AssistantPanelView.swift MalDaze/LearningAssistant/LearningAssistantViewModel.swift MalDazeTests/LearningAssistantTests.swift`
- Pending: manual desktop QA for draft review, estimate edits, option effects, hard deadline behavior, and activation guard.
