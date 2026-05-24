# ITEM-002 Swift API Client TDD Report

Timestamp: 2026-05-23T19:02:26Z

Change: `introduce-study-views`

Tasks:

- 3.1 Write failing Swift model/client tests for Today, Project Overview, Calendar Load, and task completion refresh payloads.
- 3.2 Implement Swift API models and client methods for study views.

## RED

Initial RED:

- `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -destination 'platform=macOS' -only-testing:MalDazeTests/AssistantModelDecodingTests`
- Failure: missing `StudyTodayView`, `StudyProjectOverview`, and `StudyCalendarLoad` types.

Review-driven RED:

- Missing `TaskCompletionResult`.
- `completeTask` returned `Void`, so the backend `task_id` / `completed_at` payload was not decoded.
- URLProtocol-backed tests could not instantiate a test `AssistantAPIClient(baseURL:session:)`.
- Preview fixture still used the old `completeTask -> Void` protocol witness.

## GREEN

Implemented Swift API support:

- Added `StudyTodayView` and `StudyViewTask`.
- Added `StudyProjectOverview` and `StudyProjectSummary`.
- Added `StudyCalendarLoad` and `StudyCalendarDay`.
- Added `TaskCompletionResult`.
- Added `fetchStudyTodayView()`, `fetchStudyProjectOverview()`, and `fetchStudyCalendarLoad(start:end:)` to the protocol and concrete client.
- Updated `completeTask(id:actualMinutes:)` to decode and return `TaskCompletionResult`.
- Added an injectable `AssistantAPIClient(baseURL:session:)` initializer for URLProtocol-backed tests.
- Replaced manual query-string splitting with `URLComponents` / `URLQueryItem`.
- Updated the AssistantPanel preview fixture to return `TaskCompletionResult`.

## REFACTOR

- Shared safe http/https URL validation between existing resource decoding and v2 study-view task decoding.
- Kept ViewModel/UI state changes out of this slice; 3.3/3.4 will wire the new API models into app state.

## Reviews

First code-quality review requested changes:

- Replace fragile calendar query-string construction with robust query items and real client tests.
- Decode the backend task completion payload instead of discarding it.

Second code-quality review requested one fixture fix:

- Update `AssistantPanelFixtureAPIClient.completeTask` to match the new protocol return type.

Final spec review: APPROVED.

Final focused verification passed after all fixes.

## Verification

- `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -destination 'platform=macOS' -only-testing:MalDazeTests/AssistantModelDecodingTests`: `** TEST SUCCEEDED **`.
- `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -destination 'platform=macOS' -only-testing:MalDazeTests/LearningAssistantUISourceTests -only-testing:MalDazeTests/AssistantModelDecodingTests`: `** TEST SUCCEEDED **`.
- `git diff --check`: PASS.
