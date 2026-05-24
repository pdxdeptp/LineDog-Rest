# ITEM-004 6.3-6.4 TDD Report: Swift Smart Mode ViewModel

## Scope

- Change: `introduce-study-smart-mode`
- Tasks: 6.3 and 6.4
- Target files:
  - `MalDaze/LearningAssistant/LearningAssistantViewModel.swift`
  - `MalDazeTests/LearningAssistantTests.swift`
  - `openspec/changes/introduce-study-smart-mode/tasks.md`

## RED

- Initial RED: focused `LearningAssistantViewModelTests` failed because `LearningAssistantViewModel` did not expose smart-mode state or proposal methods.
- Spec-review RED: after-adjustment apply tests failed because ViewModel did not preserve previous red-state context for apply, and stale handling used `stale` instead of backend `stale_proposal`.
- Quality-review RED: failure-path tests failed because stale proposal context was not cleared, facts refresh failure could still generate proposals, fresh briefing retained old proposal messages, and apply refresh failure could be masked by calendar refresh.

## GREEN / REFACTOR

- Added ViewModel smart-mode state for enabled flag, morning briefing, proposal options, proposal message, and apply loading.
- Dashboard refresh now loads v2 facts first, then checks persisted smart-mode setting; default mode stays silent while enabled mode fetches smart morning briefing/options through the new smart-mode client methods.
- Added ignore and apply methods for current smart proposals without touching legacy `chatMessages` or `currentProposal`.
- Added after-adjustment red-state gating based on newly created expected-late project ids or over-capacity dates; lag alone remains quiet.
- Preserved after-adjustment previous red-state context by proposal id and submits it during apply.
- Prevented stale context leaks, rejects old/non-current options, maps backend `stale_proposal`, and avoids masking failed fact refreshes.
- Marked OpenSpec tasks 6.3 and 6.4 complete.

## Review Gates

- Spec Compliance Review: initially BLOCKED for missing after-adjustment apply context and stale status mismatch.
- Spec Compliance Re-review: PASS.
- Code Quality Review: initially CHANGES_REQUESTED for stale context cleanup, refresh failure masking, and stale message retention.
- Code Quality Re-review: CHANGES_REQUESTED for apply refresh failure masking.
- Code Quality Final Re-review: APPROVED.

## Verification

- `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -only-testing:MalDazeTests/LearningAssistantViewModelTests -quiet`: PASS.
- `openspec validate introduce-study-smart-mode --strict`: PASS.
- `git diff --check`: PASS.

## Remaining Risk

- Settings toggle and visible smart-mode UI surfaces remain tasks 7.1-7.4.
- App-level Computer Use verification remains task 8.3 after UI surfaces exist.
