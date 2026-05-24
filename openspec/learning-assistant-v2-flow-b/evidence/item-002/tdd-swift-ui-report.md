# ITEM-002 Swift UI TDD Report

## Scope

- OpenSpec change: `introduce-study-views`
- Tasks: 4.1, 4.2, 4.3
- Files changed by UI worker/repair:
  - `MalDaze/LearningAssistant/AssistantPanelView.swift`
  - `MalDaze/LearningAssistant/LearningAssistantViewModel.swift`
  - `MalDazeTests/LearningAssistantTests.swift`

## RED

- Initial RED command:
  - `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -destination 'platform=macOS' -only-testing:MalDazeTests/LearningAssistantUISourceTests`
- Initial failures:
  - Missing first-class `projectOverview` and `calendar` panel tabs.
  - Missing `ProjectOverviewView`.
  - Missing `StudyCalendarLoadView`.
  - Today UI did not expose v2 persisted Today facts.
  - Calendar source did not yet prove read-only behavior.
- Review-driven RED command:
  - `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -destination 'platform=macOS' -only-testing:MalDazeTests/LearningAssistantUISourceTests`
- Review-driven failures:
  - Calendar default window only covered one week instead of the next several weeks.
  - Calendar default fetch did not guard against in-flight duplicate requests.
  - Project Overview progress percentage did not share the clamped ratio helper used by the progress bar.
  - Project status/deadline display did not format backend values into user-facing labels.

## GREEN

- Added first-class bottom navigation entries for Today, Project Overview, and Calendar.
- Added v2 Today facts to the dashboard surface without using `TodayBriefing.highlights` as the v2 source of truth.
- Added minimal Project Overview UI for active projects and completed history.
- Added read-only Calendar Load UI over a 28-day default window.
- Added source tests proving Calendar has no drag/reschedule/add/delete wiring in this slice.
- Repaired review blockers:
  - `StudyCalendarLoadView` uses `defaultCalendarWindowDayOffset = 27`.
  - `fetchDefaultWindowIfNeeded()` skips loaded and in-flight requests.
  - Project progress text and bar share `clampedProgressRatio(for:)`, including non-finite handling.
  - Project status maps `active` to `进行中` and `completed` to `已完成`.
  - Missing deadline displays `无截止日期`.

## Verification

- `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -destination 'platform=macOS' -only-testing:MalDazeTests/LearningAssistantUISourceTests`: `** TEST SUCCEEDED **`.
- `openspec validate introduce-study-views --strict`: PASS.
- `git diff --check`: PASS.

## Reviews

- Spec compliance re-review: APPROVED.
- Code quality re-review: APPROVED.

## Remaining Work

- Run final item verification across backend, Swift model/view-model/UI tests.
- Use Computer Use/App Use on the current checkout app to verify Today, completion refresh, Project Overview active/history, and Calendar load behavior.
