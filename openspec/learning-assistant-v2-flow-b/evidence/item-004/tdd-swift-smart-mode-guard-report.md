# ITEM-004 7.3-7.4 TDD Report: Swift Smart Mode Guards

## Scope

- Change: `introduce-study-smart-mode`
- Tasks: 7.3 and 7.4
- Target files:
  - `MalDazeTests/LearningAssistantTests.swift`
  - `MalDaze/LearningAssistant/AssistantPanelView.swift`
  - `MalDaze/LearningAssistant/LearningAssistantViewModel.swift`
  - `openspec/changes/introduce-study-smart-mode/tasks.md`

## RED

- Command:
  `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -parallel-testing-enabled NO -only-testing:MalDazeTests/LearningAssistantViewModelTests -only-testing:MalDazeTests/LearningAssistantUISourceTests -quiet`
- Result: FAIL, exit 65.
- Expected failures:
  - `LearningAssistantUISourceTests.testAssistantPanelSmartProposalCardsAreParallelPreviewOnlyWithPerOptionApplyAndIgnore`
  - `LearningAssistantUISourceTests.testAssistantPanelSmartProposalStripUsesVisibleOptionsAndAvoidsLegacyChatState`
  - `LearningAssistantViewModelTests.testDisabledStudySmartModeRejectsStrayProposalApplyWithoutSmartOrLegacyCalls`
- Failure reason: `StudySmartOptionsStrip` still iterated unfiltered `vm.studySmartProposalOptions`, and `applyStudySmartProposal(_:)` could call smart proposal apply when local smart mode was disabled and stale proposal state remained in memory.

## GREEN

- Command:
  `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -parallel-testing-enabled NO -only-testing:MalDazeTests/LearningAssistantViewModelTests -only-testing:MalDazeTests/LearningAssistantUISourceTests -quiet`
- Result: PASS.
- Notes:
  - Dashboard/default-mode red-state ViewModel coverage now proves rolled lag, expected-late, and over-capacity facts remain present while stray smart state is cleared and no smart/v1 endpoints are called.
  - Disabled smart mode now rejects stale local proposal apply actions before calling `applyStudySmartProposal`, legacy chat endpoints, dashboard fact refreshes, or calendar refreshes.
  - `StudySmartOptionsStrip` now renders only `visibleOptions`, preserving placement filters before card creation and Apply wiring.
  - Source guards prove the smart proposal strip does not reference `ChatView`, `chatMessages`, `currentProposal`, `sendMessage`, `confirmProposal`, or `fetchTodayBriefing`.

## Review Notes

- Spec Compliance Review: PASS for 7.3-7.4. Default mode remains fact-only even with lag, expected-late, and over-capacity data; disabled smart mode does not show/apply stale smart proposals; smart-mode UI source avoids legacy chat proposal state.
- V1 Isolation Review: PASS. The focused tests assert no `/api/today-briefing` path via `fetchTodayBriefing`, no old chat send/confirm counters, and no `chatMessages`/`currentProposal` mutation on smart proposal paths.
- Code Quality Review: PASS. Changes are limited to local UI/ViewModel guards and tests; no API client/model expansion was needed. Remaining xcodebuild warnings are pre-existing Swift 6 concurrency warnings outside this guard slice.

## Modified Files

- `MalDazeTests/LearningAssistantTests.swift`
- `MalDaze/LearningAssistant/AssistantPanelView.swift`
- `MalDaze/LearningAssistant/LearningAssistantViewModel.swift`
- `openspec/changes/introduce-study-smart-mode/tasks.md`
- `openspec/learning-assistant-v2-flow-b/evidence/item-004/tdd-swift-smart-mode-guard-report.md`

## Review Fix: Message Placement And Same-Id Stale Apply

- Review state: CHANGES_REQUESTED, then addressed in this guard slice.
- RED command:
  `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -parallel-testing-enabled NO -only-testing:MalDazeTests/LearningAssistantViewModelTests -only-testing:MalDazeTests/LearningAssistantUISourceTests -quiet`
- RED result: FAIL, exit 65.
- Expected failures:
  - `LearningAssistantUISourceTests.testAssistantPanelSmartProposalStripUsesVisibleOptionsAndAvoidsLegacyChatState`
  - `LearningAssistantUISourceTests.testStudySmartOptionsMessagesRequireMatchingPlacementContext`
  - `LearningAssistantViewModelTests.testApplyRejectsCapturedStudySmartProposalWhenSameIdSignatureChanged`
- GREEN command:
  `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -parallel-testing-enabled NO -only-testing:MalDazeTests/LearningAssistantViewModelTests -only-testing:MalDazeTests/LearningAssistantUISourceTests -quiet`
- GREEN result: PASS.
- Fixes:
  - Added `studySmartProposalMessageTrigger` metadata and passed it into `StudySmartOptionsFilter.visibleMessage` so dashboard messages render only for `.morning` context and adjustment messages render only for `.afterAdjustment` context.
  - Kept the existing helper overload for option-backed messages, but made adjustment messages require an adjustment-visible option instead of showing any global message.
  - `applyStudySmartProposal(_:)` now resolves the current option by id, compares `trigger` and `signature`, locally rejects captured stale options without an API call, preserves the current option list, and scopes the stale message to the current option's placement.
  - The apply request now submits the current stored option rather than the caller-captured option.

## Review Fix: Dashboard Message Parent Gate

- Review state: CHANGES_REQUESTED, then addressed in this guard slice.
- RED command:
  `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -parallel-testing-enabled NO -only-testing:MalDazeTests/LearningAssistantViewModelTests -only-testing:MalDazeTests/LearningAssistantUISourceTests -quiet`
- RED result: FAIL, exit 65.
- Expected failure:
  - `LearningAssistantUISourceTests.testAssistantPanelDashboardSmartSectionVisibilityUsesMorningScopedStateOnly`
- GREEN command:
  `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -parallel-testing-enabled NO -only-testing:MalDazeTests/LearningAssistantViewModelTests -only-testing:MalDazeTests/LearningAssistantUISourceTests -quiet`
- GREEN result: PASS.
- Fixes:
  - Added direct coverage for the `messageTrigger:` overload proving `.morning` messages with empty options are dashboard-visible only, and `.afterAdjustment` messages with empty options are adjustment-visible only.
  - Added `dashboardVisibleStudySmartMessage` and included it in `studySmartDashboardSection`'s parent render gate, so a dashboard-scoped message can render even without a briefing or visible options.
  - The dashboard helper passes `vm.studySmartProposalMessageTrigger` through `StudySmartOptionsFilter.visibleMessage`.

## Review Fix: Settings And Briefing Failure Message Scope

- Review state: CHANGES_REQUESTED, then addressed in this guard slice.
- RED command:
  `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -parallel-testing-enabled NO -only-testing:MalDazeTests/LearningAssistantViewModelTests -only-testing:MalDazeTests/LearningAssistantUISourceTests -quiet`
- RED result: FAIL, exit 65.
- Expected failures:
  - Build/test failure because `LearningAssistantViewModel` did not expose `studySmartSettingsMessage`.
  - Existing briefing-failure path set `studySmartProposalMessageTrigger` to `nil`, hiding the message from dashboard empty-option rendering.
- GREEN command:
  `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -parallel-testing-enabled NO -only-testing:MalDazeTests/LearningAssistantViewModelTests -only-testing:MalDazeTests/LearningAssistantUISourceTests -quiet`
- GREEN result: PASS.
- Fixes:
  - Added `studySmartSettingsMessage` for settings-update failures and rendered it in the Settings smart-mode section without legacy chat state.
  - Setting update failures now clear proposal message state and write the settings-specific message instead.
  - Successful setting updates clear `studySmartSettingsMessage`.
  - Briefing load failure after enabling smart mode now sets the existing proposal message with `.morning` trigger scope, making it dashboard-visible with empty options and hidden from adjustment placement.

## Remaining Risk

- Full task-8 verification and manual app QA remain pending outside this worker slice.
- The focused test command still emits existing project warnings, but no new warning required a guard-code change.
