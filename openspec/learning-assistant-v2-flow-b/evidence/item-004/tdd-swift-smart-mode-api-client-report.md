# ITEM-004 6.1-6.2 TDD Report: Swift Smart Mode API Client

## Scope

- Change: `introduce-study-smart-mode`
- Tasks: 6.1 and 6.2
- Target files:
  - `MalDaze/LearningAssistant/AssistantAPIClient.swift`
  - `MalDaze/LearningAssistant/AssistantAPIClientProtocol.swift`
  - `MalDazeTests/LearningAssistantTests.swift`
  - `openspec/changes/introduce-study-smart-mode/tasks.md`

## RED

- Initial RED: focused `AssistantModelDecodingTests` failed because smart-mode Swift models and client methods were missing.
- Contract RED after spec review: focused tests failed because the first Swift contract used synthetic issue/proposal/request/status fields instead of the real backend JSON shapes.
- Apply-context RED after code review: focused tests failed because `StudySmartProposalApplyRequest` could not encode after-adjustment previous red-state fields required by the backend.

## GREEN / REFACTOR

- Added Swift models for smart-mode settings, morning briefing issues, proposal options, proposal generation request/response, and proposal apply request/result.
- Extended `AnyCodable` to carry nested arrays and dictionaries used by backend `preview`, `reason`, and `signature_payload` data.
- Added protocol methods, concrete `AssistantAPIClient` calls, and mock support for:
  - `GET /api/study-smart-mode/settings`
  - `PUT /api/study-smart-mode/settings`
  - `GET /api/study-smart-mode/morning-briefing`
  - `POST /api/study-smart-mode/proposals`
  - `POST /api/study-smart-mode/proposals/apply`
- Aligned Swift tests/models with the backend contract:
  - briefing issue fields: `type`, `project_id`, `task_id`, `rolled_day_count`, `date`
  - proposal `reason` object
  - integer `signature_version`
  - `preview.mutates`
  - `previous_expected_late_project_ids`
  - `previous_over_capacity_dates`
  - `stale_proposal` apply status and disabled-smart-mode message
- Marked OpenSpec tasks 6.1 and 6.2 complete.

## Review Gates

- Spec Compliance Review: initially BLOCKED for backend JSON contract mismatch.
- Spec Compliance fix: updated models and tests to match actual backend request, response, status, and payload shapes.
- Spec Compliance Re-review: PASS.
- Code Quality Review: initially CHANGES_REQUESTED because apply requests did not preserve after-adjustment previous red-state context.
- Code Quality fix: added optional previous expected-late project ids and over-capacity dates to `StudySmartProposalApplyRequest` with request-body tests.
- Code Quality Re-review: APPROVED.

## Verification

- `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -only-testing:MalDazeTests/AssistantModelDecodingTests -quiet`: PASS.
- `openspec validate introduce-study-smart-mode --strict`: PASS.
- `git diff --check`: PASS.

## Remaining Risk

- ViewModel smart-mode state, refresh sequencing, ignore/apply UI state, and after-adjustment trigger gating remain tasks 6.3-6.4.
- Swift UI surfaces and app-level UI verification remain later 7.x/10.x tasks.
