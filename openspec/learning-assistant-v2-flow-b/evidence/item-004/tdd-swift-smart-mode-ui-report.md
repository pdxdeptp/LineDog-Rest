# ITEM-004 7.1-7.2 TDD Report: Swift Smart Mode UI

## Scope

- Change: `introduce-study-smart-mode`
- Tasks: 7.1 and 7.2
- Target files:
  - `MalDazeTests/LearningAssistantTests.swift`
  - `MalDaze/LearningAssistant/AssistantPanelView.swift`
  - `MalDaze/LearningAssistant/LearningAssistantViewModel.swift`
  - `openspec/changes/introduce-study-smart-mode/tasks.md`

## RED

- Command:
  `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -only-testing:MalDazeTests/LearningAssistantUISourceTests -quiet`
- Result: FAIL, exit 65.
- Expected failures:
  - `testAssistantPanelSettingsWiresStudySmartModeToggleToViewModelSettingUpdate`
  - `testAssistantPanelDashboardDisplaysStudySmartMorningBriefingAndProposalSurface`
  - `testAssistantPanelSmartProposalCardsAreParallelPreviewOnlyWithPerOptionApplyAndIgnore`
  - `testAssistantPanelAdjustmentContextDisplaysStudySmartOptionsWithoutLegacyChatState`
- Failure reason: Settings lacked a smart-mode toggle and ViewModel setter; Dashboard and adjustment contexts lacked smart briefing/proposal surfaces; no side-by-side proposal cards with per-option Apply and Ignore existed.

## GREEN

- Command:
  `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -only-testing:MalDazeTests/LearningAssistantUISourceTests -quiet`
- Result: PASS.
- Notes:
  - Added Settings toggle copy stating smart mode is off by default.
  - Added minimal `updateStudySmartModeSetting(_:)` ViewModel setter because UI had no persisted-setting entry point.
  - Added Dashboard smart morning briefing surface wired to `vm.studySmartMorningBriefing`, `vm.studySmartProposalOptions`, and `vm.studySmartProposalMessage`.
  - Added horizontal proposal option strip using `ScrollView(.horizontal)` and `LazyHStack`, with `ForEach(vm.studySmartProposalOptions, id: \.id)`, per-option `Task { await vm.applyStudySmartProposal(option) }`, and Ignore via `vm.ignoreStudySmartProposals()`.
  - Added adjustment-context smart option strip filtered to after-adjustment options.

## Review Notes

- Spec Compliance Review: PASS for 7.1-7.2. UI is gated by `vm.isStudySmartModeEnabled`; proposal display is preview-only; Apply delegates only to `applyStudySmartProposal(_:)`; Ignore delegates only to `ignoreStudySmartProposals()`.
- V1 Isolation Review: PASS for the new smart UI source tests. Smart-mode UI sections do not call `ChatView`, `sendMessage`, `confirmProposal`, `chatMessages`, or `currentProposal`.
- Code Quality Review: PASS with residual project warnings. Focused `xcodebuild` still emits pre-existing Swift 6 Sendable/main-actor warnings outside this slice.

## Code Quality Follow-up

- Review state: CHANGES_REQUESTED, then addressed in the same 7.1-7.2 scope.
- RED command:
  `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -only-testing:MalDazeTests/LearningAssistantViewModelTests/testEnableStudySmartModeReportsBriefingFailureWithoutClearingPersistedEnabledState -only-testing:MalDazeTests/LearningAssistantViewModelTests/testStudySmartModeSettingUpdateUsesLatestUserIntentWhenRequestsCompleteOutOfOrder -only-testing:MalDazeTests/LearningAssistantUISourceTests/testAssistantPanelSmartProposalPlacementsFilterTriggers -quiet`
- RED result: FAIL, exit 65. Failures covered smart-mode enable briefing fetch failure handling, out-of-order toggle requests, and dashboard/adjustment proposal trigger filtering.
- GREEN result for the same command: PASS.
- Broader focused command:
  `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -only-testing:MalDazeTests/LearningAssistantViewModelTests -only-testing:MalDazeTests/LearningAssistantUISourceTests -quiet`
- Broader focused result: PASS.
- Fixes:
  - `updateStudySmartModeSetting(_:)` now uses a request sequence so stale toggle responses cannot overwrite the latest user intent.
  - Enabling smart mode no longer calls the dashboard refresh helper that swallows briefing errors; a failed smart morning briefing now preserves persisted enabled state, sets `isOffline`, and shows a clear message.
  - Dashboard smart proposal placement filters `.morning`; adjustment placement filters `.afterAdjustment`.

## Code Quality Re-review Follow-up

- Review state: CHANGES_REQUESTED, then addressed in the same 7.1-7.2 scope.
- RED command:
  `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -only-testing:MalDazeTests/LearningAssistantUISourceTests/testAssistantPanelDashboardSmartSectionVisibilityUsesMorningScopedStateOnly -only-testing:MalDazeTests/LearningAssistantUISourceTests/testStudySmartOptionsPlacementHelperFiltersByTrigger -quiet`
- RED result: FAIL, exit 65. Failures covered the missing morning-scoped dashboard visibility guard and the missing pure placement filter helper.
- GREEN result for the same command: PASS.
- Broader focused command:
  `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -only-testing:MalDazeTests/LearningAssistantViewModelTests -only-testing:MalDazeTests/LearningAssistantUISourceTests -quiet`
- Broader focused result: PASS.
- Final impacted focused command:
  `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -only-testing:MalDazeTests/LearningAssistantViewModelTests/testEnableStudySmartModeReportsBriefingFailureWithoutClearingPersistedEnabledState -only-testing:MalDazeTests/LearningAssistantViewModelTests/testStudySmartModeSettingUpdateUsesLatestUserIntentWhenRequestsCompleteOutOfOrder -only-testing:MalDazeTests/LearningAssistantUISourceTests/testAssistantPanelDashboardSmartSectionVisibilityUsesMorningScopedStateOnly -only-testing:MalDazeTests/LearningAssistantUISourceTests/testStudySmartOptionsPlacementHelperFiltersByTrigger -only-testing:MalDazeTests/LearningAssistantUISourceTests/testAssistantPanelSmartProposalPlacementsFilterTriggers -quiet`
- Final impacted focused result: PASS.
- Broader non-parallel focused command:
  `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -parallel-testing-enabled NO -only-testing:MalDazeTests/LearningAssistantViewModelTests -only-testing:MalDazeTests/LearningAssistantUISourceTests -quiet`
- Broader non-parallel focused result: PASS.
- Validation:
  - `openspec validate introduce-study-smart-mode --strict`: PASS.
  - `git diff --check`: PASS.
- Warning check: latest focused log for this checkpoint did not emit the new `updateStudySmartModeSetting(_:)` `sending api/self.api risks causing data races` warning. The final re-review below replaces the temporary unsafe-nonisolated API reference with a Sendable protocol/client conformance.
- Fixes:
  - Dashboard smart section visibility now depends only on smart mode being enabled plus morning briefing or dashboard-visible `.morning` proposal options.
  - Dashboard no longer uses unfiltered `vm.studySmartProposalOptions.isEmpty` or global `vm.studySmartProposalMessage` to decide whether to render.
  - Added `StudySmartOptionsFilter.visibleOptions(_:placement:)` and behavior coverage proving `.dashboard` keeps `.morning` options while `.adjustment` keeps `.afterAdjustment` options.

## Code Quality Final Re-review Follow-up

- Review state: CHANGES_REQUESTED, then addressed in the same 7.1-7.2 scope.
- RED command:
  `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -only-testing:MalDazeTests/LearningAssistantUISourceTests/testLearningAssistantAPIInjectionUsesSendableProtocolWithoutUnsafeBypass -only-testing:MalDazeTests/LearningAssistantUISourceTests/testStudySmartOptionsDashboardMessageRequiresDashboardVisibleOption -quiet`
- RED result: FAIL, exit 65. Failure covered the missing placement-scoped proposal message helper; the same RED test batch also added a source guard against `nonisolated(unsafe) let api`.
- GREEN command:
  `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -only-testing:MalDazeTests/LearningAssistantViewModelTests/testEnableStudySmartModeReportsBriefingFailureWithoutClearingPersistedEnabledState -only-testing:MalDazeTests/LearningAssistantViewModelTests/testStudySmartModeSettingUpdateUsesLatestUserIntentWhenRequestsCompleteOutOfOrder -only-testing:MalDazeTests/LearningAssistantUISourceTests/testLearningAssistantAPIInjectionUsesSendableProtocolWithoutUnsafeBypass -only-testing:MalDazeTests/LearningAssistantUISourceTests/testAssistantPanelDashboardSmartSectionVisibilityUsesMorningScopedStateOnly -only-testing:MalDazeTests/LearningAssistantUISourceTests/testAssistantPanelSmartProposalCardsAreParallelPreviewOnlyWithPerOptionApplyAndIgnore -only-testing:MalDazeTests/LearningAssistantUISourceTests/testAssistantPanelSmartProposalPlacementsFilterTriggers -only-testing:MalDazeTests/LearningAssistantUISourceTests/testStudySmartOptionsPlacementHelperFiltersByTrigger -only-testing:MalDazeTests/LearningAssistantUISourceTests/testStudySmartOptionsDashboardMessageRequiresDashboardVisibleOption -quiet`
- GREEN result: PASS.
- Warning check: focused GREEN log did not contain `updateStudySmartModeSetting`, `sending api`, or `sending self.api`. Remaining Swift 6 warnings in the log are existing non-update paths, including `StudySmartProposalApplyRequest` in `applyStudySmartProposal`, API client SSE event yielding, and unrelated window/reminder warnings.
- Fixes:
  - Removed `nonisolated(unsafe) let api` from `LearningAssistantViewModel`.
  - Made `AssistantAPIClientProtocol` inherit `Sendable` and marked production `AssistantAPIClient` as `@unchecked Sendable`.
  - Added `StudySmartOptionsFilter.visibleMessage(_:options:placement:)`; dashboard proposal strips now show `studySmartProposalMessage` only when dashboard-visible `.morning` options exist, while adjustment placement can still surface adjustment messages.

## Remaining Risk

- Tasks 7.3 and 7.4 remain open for broader default-mode red-state/source guard coverage.
- Manual app verification remains task 8.3.
- A default-parallel broader rerun surfaced an intermittent existing `testFetchStudyCalendarLoadKeepsLatestRangeWhenOlderRequestFinishesLast` failure; the single test passed immediately afterward and the broader focused suite passed with `-parallel-testing-enabled NO`. No calendar-load production or test-support changes were made because that is outside ITEM-004 smart-mode UI scope.
