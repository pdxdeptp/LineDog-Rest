# TDD Report: Swift Study Views ViewModel

## Scope

- OpenSpec change: `introduce-study-views`
- Tasks: 3.3 / 3.4
- Files changed:
  - `MalDaze/LearningAssistant/LearningAssistantViewModel.swift`
  - `MalDazeTests/LearningAssistantTests.swift`

## RED

Initial failing command:

```bash
xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -destination 'platform=macOS' -only-testing:MalDazeTests/LearningAssistantViewModelTests
```

Failure summary: `LearningAssistantViewModel` was missing explicit v2 study-view state and APIs, including `studyTodayView`, `studyProjectOverview`, `studyCalendarLoad`, and `fetchStudyCalendarLoad(start:end:)`.

Review-driven failing command:

```bash
xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -destination 'platform=macOS' -only-testing:MalDazeTests/LearningAssistantViewModelTests/testDashboardMapsStudyProjectTitleBeforeResourceTitleForVisibleTasks -only-testing:MalDazeTests/LearningAssistantViewModelTests/testFetchStudyCalendarLoadKeepsLatestRangeWhenOlderRequestFinishesLast -only-testing:MalDazeTests/LearningAssistantViewModelTests/testOlderStudyCalendarLoadCompletionDoesNotClearNewerLoadingState
```

Failure summary: project/resource title mapping preferred resource title over project title, and an older Calendar load request could overwrite a newer range.

## GREEN

Final targeted Swift verification:

```bash
xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -destination 'platform=macOS' -only-testing:MalDazeTests/LearningAssistantViewModelTests -only-testing:MalDazeTests/AssistantModelDecodingTests
```

Result: `** TEST SUCCEEDED **`.

OpenSpec verification:

```bash
openspec validate introduce-study-views --strict
```

Result: `Change 'introduce-study-views' is valid`.

Diff hygiene:

```bash
git diff --check
```

Result: PASS.

## Behavior Implemented

- Default dashboard refresh now reads dedicated v2 study views with `fetchStudyTodayView()` and `fetchStudyProjectOverview()`.
- ViewModel stores first-class `studyTodayView`, `studyProjectOverview`, and `studyCalendarLoad` state.
- Legacy `TodayBriefing.highlights` is no longer the v2 dashboard source of truth; dashboard highlights are generated from factual Today task count and total target minutes.
- Task completion refreshes persisted Today and Project Overview facts, and refreshes current Calendar load if a Calendar range is already loaded.
- Calendar load is read-only ViewModel state and uses latest-request-wins sequencing so older requests cannot overwrite newer ranges or clear a newer loading state.
- Visible v2 Today task rows prefer project title over resource title when mapping into the existing `AssistantTask` compatibility surface.

## Reviews

- Spec compliance review: APPROVED.
- Code quality review: CHANGES_REQUESTED for Calendar race, project-title mapping, and v2 fixture coverage.
- Code quality re-review after fixes: APPROVED; all three blockers closed.

