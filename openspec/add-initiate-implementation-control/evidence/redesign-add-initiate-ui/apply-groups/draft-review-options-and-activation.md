# Apply Group Evidence: draft-review-options-and-activation

- Automation: add-initiate-changes
- Change: redesign-add-initiate-ui
- Checkpoint: redesign-add-initiate-ui:apply:draft-review-options-and-activation
- Completed at: 2026-05-25T16:35:21Z
- Run counter: 40
- Task ids: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8

## Scope

Implemented the Add / Initiate draft review and activation surface for the already-produced draft states. This group stayed inside the Swift ViewModel/UI review layer and tests:

- Summary-first draft review projection with first-week schedule, assumptions, buffer/fallback/risk facts, source details, and explicit full-schedule expansion.
- Canonical infeasibility option labels, hard-deadline filtering, and option-effect progress/result handling without creating active work.
- Local per-task estimate edit controls for option effects, with backend-compatible `estimate_edits` payload shape.
- Activation success, stale-draft blocking, activation failure preservation, retry, edit, and cancel UI paths.
- Test isolation fix for `autoLoadWhenReady: false` so tests/previews do not respond to global backend-ready notifications.

Out of scope for this group:

- Backend scheduler/compiler algorithm changes.
- Active Today/Calendar/smart-mode no-noise verification, reserved for `noise-boundaries-and-active-refresh`.
- Real-context QA and final task checkbox updates, reserved for `real-context-qa-and-final-verification`.

## TDD Evidence

RED examples observed during the group:

- Draft review and activation UI tests initially failed before the new review projection and UI controls existed.
- `testAutoLoadDisabledIgnoresBackendReadyNotificationUntilDashboardOpen` failed because `autoLoadWhenReady: false` ViewModels still started in connecting mode and responded to global `.backendDidBecomeReady` notifications.
- `testOptionEffectSendsParametersFromAnchorsFocusedAnswerAndLocalTaskEdits` failed after tightening the expectation to backend-compatible `estimate_edits: [taskId: minutesInt]`.

GREEN implementation:

- Added typed draft review projection models and ViewModel helpers for summary, schedule, risk, source, fallback, infeasible options, stale activation checks, option parameters, activation-failure preservation, and scoped local task edit drafts.
- Added SwiftUI cards for infeasible review, draft review, activation failure, expansion controls, local estimate edit rows, and option/activation actions.
- Adjusted `autoLoadWhenReady == false` initialization and backend-ready observer guard so disabled auto-load does not trigger dashboard fetches from external notifications.
- Changed `estimate_edits` payload to `[String: Int]`, matching backend `apply_schedule_option`.

## Review Record

Spec compliance review:

- First review requested fixes for activation retry eligibility, option-effect package preservation, expansion controls, infeasible facts, and compiler recompute handoff.
- Second review requested real per-task edit controls and low-calibration risk projection.
- Final spec review approved the group after fixes.

Code quality review:

- First review requested fixes for option parameters, activation-failure package preservation, stale package version checks, camelCase parsing, raw-id leakage, scoped task edit cleanup, and brittle tests.
- Re-review requested exact backend option parameter keys and clearing task edit drafts after anchor reconfirmation.
- Final review requested `estimate_edits` value-shape correction from nested dictionaries to `[taskId: minutesInt]`.
- Final code quality re-review returned APPROVED with no remaining P0/P1 blockers.

## Verification

Commands run fresh after final fixes:

- `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -parallel-testing-enabled NO -only-testing:MalDazeTests/LearningAssistantViewModelTests -only-testing:MalDazeTests/LearningAssistantUISourceTests -quiet`
  - Exit code: 0
  - Summary: focused Swift ViewModel/UI source tests passed.
- `openspec validate redesign-add-initiate-ui --strict`
  - Exit code: 0
  - Summary: valid.
- `git diff --check -- MalDaze/LearningAssistant/AssistantPanelView.swift MalDaze/LearningAssistant/LearningAssistantViewModel.swift MalDazeTests/LearningAssistantTests.swift`
  - Exit code: 0
  - Summary: no whitespace errors.

## Artifacts

- `MalDaze/LearningAssistant/AssistantPanelView.swift`
  - sha256: `9d368464ec8327a81c527134b70b7c4f76f74cf60f101b2ca47def3d70b078e9`
- `MalDaze/LearningAssistant/LearningAssistantViewModel.swift`
  - sha256: `d94a5c6153e06f1aebe77f0052b60d5169fbdc26ce4e1b50f523b54ec38340ab`
- `MalDazeTests/LearningAssistantTests.swift`
  - sha256: `5452c939e14fde2ccca5f54b43294895e82bf8117b71500bf280263b0334a9f0`

## Next Checkpoint

- redesign-add-initiate-ui:apply:noise-boundaries-and-active-refresh
