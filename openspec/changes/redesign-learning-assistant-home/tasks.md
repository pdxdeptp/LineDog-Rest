## 1. Baseline And Red Tests

- [ ] 1.1 Run baseline verification before implementation in the selected workspace: `cd assistant_backend && pytest`, then `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -destination 'platform=macOS'`
- [ ] 1.2 Add failing backend tests for `GET /api/today-briefing` task payloads including existing task fields plus `resource_url` and `unit_url`
- [ ] 1.3 Add failing Swift decoding tests for `AssistantTask.resourceURL` and `AssistantTask.unitURL`, including null fallback cases
- [ ] 1.4 Add failing ViewModel tests for summary-first dashboard state, whole-column offline, empty database primary action, local task display order, task expansion state, link availability, and bottom navigation selection
- [ ] 1.5 Add failing layout/fixture tests or preview assertions for wide popover layout: left fixed column, right fixed column, adaptive learning assistant middle column

## 2. Backend Briefing Link Contract

- [ ] 2.1 Update `assistant_backend/src/agents/morning_agent.py` so each today briefing task includes `resource_url` from the associated resource and `unit_url` when available, preserving existing fields
- [ ] 2.2 Update or add backend fixtures in `assistant_backend/tests/` to cover task with resource URL, task without resource URL, and task without associated resource
- [ ] 2.3 Run focused backend tests for today's briefing link payload and confirm they pass
- [ ] 2.4 Run full backend regression verification: `cd assistant_backend && pytest`

## 3. Swift Models And Dashboard State

- [ ] 3.1 Update `MalDaze/LearningAssistant/AssistantAPIClient.swift` models so `AssistantTask` decodes optional `resource_url` and `unit_url`
- [ ] 3.2 Update `MalDaze/LearningAssistant/LearningAssistantViewModel.swift` to expose summary-first dashboard state without a system-selected next task
- [ ] 3.3 Add local presentation ordering for today's visible tasks keyed by date and task ids; do not call backend APIs or mutate task priority/scheduled_date for drag ordering
- [ ] 3.4 Add task expansion state and link availability helpers that prefer `unit_url`, fall back to `resource_url`, and expose unavailable state when neither exists
- [ ] 3.5 Update offline handling so any assistant homepage data request failure enters whole-column service-unavailable state rather than cached-content or partial-failure dashboard
- [ ] 3.6 Run focused Swift tests for model decoding and ViewModel dashboard behavior

## 4. Wide Popover Layout

- [ ] 4.1 Update `MalDaze/MenuBarContentView.swift` sizing so the desk-pet popover can use a screen-aware near-full-width content size while keeping a safe margin inside the visible screen
- [ ] 4.2 Update `MenuBarContentView` three-column layout so reminders and right controls remain fixed width while `AssistantPanelView` receives the remaining adaptive width
- [ ] 4.3 Preserve existing `NSPopover` presentation and dismiss behavior in `MalDaze/WindowManager/WindowManager.swift`; if `NSPopover` cannot support the required layout, stop and update spec before changing windowing strategy
- [ ] 4.4 Add or update tests around control panel preferred size / layout constants where feasible

## 5. Dashboard UI And Interactions

- [ ] 5.1 Replace the ready-state four-tab first screen in `MalDaze/LearningAssistant/AssistantPanelView.swift` with a summary-first dashboard
- [ ] 5.2 Add bottom fixed navigation for 首页, 添加资料, 资料进度, 调整计划; keep it outside the scrollable dashboard content and hide it in whole-column offline state
- [ ] 5.3 Implement homepage states for empty database, tasks today, all tasks completed, resources without today tasks, and deadline risk
- [ ] 5.4 Implement reorderable today task rows with a clear drag handle and local presentation ordering only
- [ ] 5.5 Implement clickable task row body expansion for light details, keeping completion and drag targets distinct
- [ ] 5.6 Implement explicit “打开链接” action in expanded task details, opening `unit_url` first and `resource_url` second; show unavailable state when no link exists
- [ ] 5.7 Keep existing Add Material, Resource Progress, and Chat/Planner surfaces reachable from bottom navigation without productizing those surfaces in this loop
- [ ] 5.8 Verify text fits within the adaptive middle column and bottom navigation labels do not overlap across expected desktop widths

## 6. Fixtures And Acceptance Evidence

- [ ] 6.1 Add SwiftUI preview fixtures or equivalent constructors for empty database, backend starting, whole-column offline, tasks today, task expanded with link, task without link, resources without today tasks, deadline risk, and wide popover layout
- [ ] 6.2 Update `docs/acceptance-checklist.md` or a focused acceptance note with homepage journey scenarios and required evidence
- [ ] 6.3 Capture or record visual evidence for wide popover layout, bottom fixed navigation, scrollable dashboard with fixed nav, task detail expansion, learning link action, drag reorder, empty database, and whole-column offline
- [ ] 6.4 Compare SwiftUI result against `openspec/changes/redesign-learning-assistant-home/mockups/home-dashboard-wide-popover.html` and document intentional differences

## 7. Reviews And Final Verification

- [ ] 7.1 Run full Swift verification: `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -destination 'platform=macOS'`
- [ ] 7.2 Run backend regression verification: `cd assistant_backend && pytest`
- [ ] 7.3 Perform spec compliance review against all delta specs in `openspec/changes/redesign-learning-assistant-home/specs/`
- [ ] 7.4 Perform code quality review for state duplication, accidental backend mutation during drag ordering, hidden navigation, overbroad error handling, popover sizing regressions, and layout overlap
- [ ] 7.5 Update this task list only after each task has passed its verification evidence

## 8. Subagent Handoff Boundaries

- [ ] 8.1 Backend contract subagent owns `assistant_backend/src/agents/morning_agent.py`, backend tests, and the `daily-morning-agent` spec compliance for link fields
- [ ] 8.2 Frontend state subagent owns `AssistantAPIClient.swift`, `AssistantAPIClientProtocol.swift`, `LearningAssistantViewModel.swift`, and model/ViewModel tests; it must not edit popover shell layout
- [ ] 8.3 Popover layout subagent owns `MenuBarContentView.swift` and any sizing tests; it must preserve `WindowManager` popover behavior unless spec is updated
- [ ] 8.4 Frontend UI subagent owns `AssistantPanelView.swift` and visual fixtures; it coordinates with ViewModel state names and does not modify backend code
- [ ] 8.5 Acceptance subagent owns acceptance documentation and visual evidence; it must not change production Swift or Python code except fixture-only support agreed with the owning subagent
