## 2026-05-29 Progress

Implemented the Add / Initiate state-boundary slice for frontend state and UI routing.

### Completed

- Added derived ViewModel states for route clarification, draft clarification, non-plan confirmation, and terminal success boundaries.
- Prevented route-level `needs_input` without a draft from calling anchor confirmation or showing a missing-draft recovery path.
- Kept draft-level `needs_input` on the existing draft context and same anchor confirmation path.
- Required explicit confirmation before reference, later-resource, one-off, and material-attachment recommendations can show terminal success.
- Added separate UI cards for route clarification, draft clarification, non-plan confirmation, and activation success.
- Preserved activation-failure recovery and active-surface refresh boundaries.

### Verification

- Passed focused Add / Initiate state-boundary Swift tests:
  `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -parallel-testing-enabled NO ...`
- Passed `LearningAssistantUISourceTests` during the UI TDD loop.
- Passed `openspec validate fix-add-initiate-state-boundaries --strict`.
- Passed `git diff --check` for touched implementation, test, and OpenSpec files.

### Notes

- No backend API response fields changed, so backend contract tests were not required for this slice.
- Full `LearningAssistantViewModelTests + LearningAssistantUISourceTests` encountered existing out-of-order async test flakiness outside Add / Initiate; the failing cases passed when rerun individually.
- Desktop manual verification remains pending for route clarification, non-plan confirmation, material attachment, activation success, and activation failure.
