# Learning Assistant Home Dashboard Acceptance Evidence

Date recorded: 2026-05-10

This note records source-level and focused-test evidence for OpenSpec change
`redesign-learning-assistant-home`, task group 6. No real screenshots were
captured in this pass.

## Recorded Evidence

| Acceptance item | Evidence source | Status |
|---|---|---|
| Wide popover layout | `MalDazeTests/ControlPanelPresentationTests.swift` source tests assert screen-aware preferred size, fixed outer columns, and adaptive `AssistantPanelView` middle column. | Recorded source-test evidence |
| Bottom fixed nav | `MalDazeTests/LearningAssistantTests.swift` source tests assert `bottomNavigationBar` plus 首页 / 添加资料 / 资料进度 / 调整计划 labels and no segmented tab picker. | Recorded source-test evidence |
| Scrollable dashboard with fixed nav | `MalDaze/LearningAssistant/AssistantPanelView.swift` keeps `activePanelContent` above a `Divider()` and `bottomNavigationBar`, while `homeDashboard` is a `List`; source tests record the structure. | Recorded source-test evidence |
| Task expansion | ViewModel tests cover `toggleTaskExpansion(_:)`; source tests assert `TaskRowView` has `onToggleExpansion`; preview fixture `taskExpandedWithLinkViewModel()` starts expanded. | Recorded source-test and fixture evidence |
| Learning link action | Decoding tests cover `resource_url` / `unit_url`; ViewModel tests cover unit-first fallback; source tests assert `打开链接`, `链接不可用`, and `NSWorkspace.shared.open`. | Recorded source-test evidence |
| Drag reorder | ViewModel tests cover local display ordering and refresh merge; source tests assert `dragHandle`, `line.3.horizontal`, and `moveVisibleTasks`. | Recorded source-test evidence |
| Empty database | Preview fixture `emptyDatabaseViewModel()` constructs empty briefing and resources; ViewModel test covers `.emptyDatabase` and `.addResource` primary action. | Recorded fixture and source-test evidence |
| Backend starting | Preview fixture `backendStartingViewModel()` sets `isConnecting=true`; `AssistantPanelView` routes `.connecting` to startup copy. | Recorded fixture evidence |
| Whole-column offline | Preview fixture `wholeColumnOfflineViewModel()` sets `isOffline=true`; source uses `.offline` branch before `readyPanel`, so bottom nav is hidden. | Recorded fixture and source-test evidence |
| Tasks today | Preview fixture `tasksTodayViewModel()` provides two visible tasks, minutes, highlights, and resources. | Recorded fixture evidence |
| Task expanded with link | Preview fixture `taskExpandedWithLinkViewModel()` expands a task with both `unitURL` and `resourceURL`. | Recorded fixture evidence |
| Task without link | Preview fixture `taskExpandedWithoutLinkViewModel()` expands a task with no URL fields. | Recorded fixture evidence |
| Resources without today tasks | Preview fixture `resourcesWithoutTodayTasksViewModel()` provides resources and no tasks. | Recorded fixture evidence |
| Deadline risk | Preview fixture `deadlineRiskViewModel()` provides a resource with `deadline_risk` status. | Recorded fixture evidence |

## Focused Test Commands

RED was confirmed with:

```bash
xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -destination 'platform=macOS' -only-testing:MalDazeTests/LearningAssistantUISourceTests/testAssistantPanelProvidesFixtureInjectionAndPreviewStateMatrix
```

Expected failure: `AssistantPanelView.swift` did not yet expose fixture injection
or the preview state matrix.

GREEN was confirmed with the same command after adding `init(viewModel:)`,
`AssistantPanelPreviewFixtures`, and the preview fixture matrix.

## Mockup Comparison

Reference mockup:
`openspec/changes/redesign-learning-assistant-home/mockups/home-dashboard-wide-popover.html`

Aligned:

- Wide shell concept: fixed reminders column, fixed controls column, adaptive learning assistant column.
- Homepage information hierarchy: summary first, task list second, tools in bottom navigation.
- Whole-column offline model: offline state replaces the assistant column and hides tool navigation.
- Task row model: reorder handle, row expansion, completion action, and explicit learning-link action are separate.

Intentional differences:

- The SwiftUI implementation uses native `List`, `.bar` background, system icons, and platform typography instead of the HTML mockup's handcrafted CSS cards and spacing.
- Preview fixtures use deterministic in-source data and do not attempt to render the full desktop popover shell; wide layout evidence is recorded through existing `MenuBarContentView` layout source tests.
- Learning links open through `NSWorkspace.shared.open`; the mockup models the action visually only.
- Deadline risk is derived from resource status/deadline fields rather than a bespoke dashboard endpoint.
- Drag ordering is local presentation state only and does not modify backend priority or scheduling.

## Manual Visual Checklist

- Open the `AssistantPanelView_Previews` group and inspect each preview name listed in the evidence table.
- Use the full app popover to confirm the assistant middle column receives extra width between fixed outer columns.
- Scroll a long dashboard and confirm the bottom navigation remains visible.
- Expand linked and unlinked task rows and confirm the link action / unavailable state matches the fixture.
- Confirm empty database and whole-column offline states do not show stale dashboard content.
