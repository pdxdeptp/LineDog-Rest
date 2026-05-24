# Fix Assistant Bottom Nav Responsiveness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make learning assistant bottom-tab clicks feel immediate and keep the Dashboard Panel open for clicks inside the panel.

**Architecture:** Keep tab selection as local SwiftUI state and keep tab data refreshes asynchronous. Harden the Dashboard Panel click-away rule in `WindowManager` so internal panel clicks are never treated as outside-dismiss events, while existing outside click and Esc behavior remain intact.

**Tech Stack:** SwiftUI, AppKit `NSPanel`/`NSEvent` monitors, XCTest source-level regression tests.

---

## File Structure

- Modify `MalDaze/LearningAssistant/AssistantPanelView.swift`: bottom-navigation item button frame, content shape, and immediate selected-state rendering.
- Modify `MalDaze/WindowManager/WindowManager.swift`: Dashboard Panel dismissal predicate and monitor call sites.
- Modify `MalDazeTests/LearningAssistantTests.swift`: source-level regression for bottom-navigation hit target and selected-state behavior.
- Modify `MalDazeTests/ControlPanelPresentationTests.swift`: source-level regression for centralized panel internal-click guard and preserved outside-click handling.
- Create or update `openspec/changes/fix-assistant-bottom-nav-responsiveness/evidence/`: verification notes after tests/manual QA.

### Task 1: Bottom Navigation Responsiveness

**Files:**
- Modify: `MalDazeTests/LearningAssistantTests.swift`
- Modify: `MalDaze/LearningAssistant/AssistantPanelView.swift`

- [ ] **Step 1: Write the failing test**

Add a test near existing assistant panel source-shape tests:

```swift
func testAssistantBottomNavigationUsesFullRectangularHitTargetsAndImmediateSelection() throws {
    let source = try readProjectSource("MalDaze/LearningAssistant/AssistantPanelView.swift")
    let buttonSource = try XCTUnwrap(
        rangeOfFunction(named: "bottomNavigationButton", in: source).map { String(source[$0]) }
    )

    XCTAssertTrue(
        buttonSource.contains("vm.selectedPanelTab = tab"),
        "Bottom navigation should update selectedPanelTab directly in the button action."
    )
    XCTAssertTrue(
        buttonSource.contains(".contentShape(Rectangle())"),
        "The full visible bottom-navigation segment should be clickable, not only icon/text glyphs."
    )
    XCTAssertTrue(
        buttonSource.contains(".frame(maxWidth: .infinity, maxHeight: .infinity)") ||
        buttonSource.contains(".frame(maxWidth: .infinity, minHeight:"),
        "Each bottom-navigation item should keep a stable equal-width hit area."
    )
    XCTAssertTrue(
        buttonSource.contains("vm.selectedPanelTab == tab"),
        "The selected item should render immediate selected-state feedback from local state."
    )
}
```

- [ ] **Step 2: Run the failing test**

Run:

```bash
xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -only-testing:MalDazeTests/LearningAssistantTests/testAssistantBottomNavigationUsesFullRectangularHitTargetsAndImmediateSelection
```

Expected: FAIL because `bottomNavigationButton` does not yet contain `.contentShape(Rectangle())`.

- [ ] **Step 3: Implement minimal UI change**

Update `bottomNavigationButton(_:)` so the label has an explicit rectangular hit target:

```swift
private func bottomNavigationButton(_ tab: AssistantPanelTab) -> some View {
    Button {
        vm.selectedPanelTab = tab
    } label: {
        VStack(spacing: 3) {
            Image(systemName: tab.iconName)
                .font(.system(size: 15, weight: .semibold))
            Text(tab.shortLabel)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .foregroundStyle(vm.selectedPanelTab == tab ? Color.accentColor : Color.secondary)
    }
    .buttonStyle(.plain)
    .help(tab.shortLabel)
}
```

- [ ] **Step 4: Run the test again**

Run the same `xcodebuild test` command.

Expected: PASS.

### Task 2: Dashboard Panel Internal Click Stability

**Files:**
- Modify: `MalDazeTests/ControlPanelPresentationTests.swift`
- Modify: `MalDaze/WindowManager/WindowManager.swift`

- [ ] **Step 1: Write the failing test**

Add a test near `testDeskPetDashboardOwnsCustomDismissBehavior`:

```swift
func testDeskPetDashboardDismissalUsesCentralInsidePanelGuard() throws {
    let source = try readProjectSource("MalDaze/WindowManager/WindowManager.swift")
    let dismissSource = try XCTUnwrap(
        rangeOfFunction(named: "installDashboardDismissMonitors", in: source).map { String(source[$0]) }
    )

    XCTAssertTrue(
        source.contains("private func dashboardPanelContainsMouseLocation("),
        "Dashboard dismissal should use one guard for inside-panel click detection."
    )
    XCTAssertTrue(
        dismissSource.contains("dashboardPanelContainsMouseLocation(mouse"),
        "Both local and global dismiss monitors should preserve clicks inside the panel."
    )
    XCTAssertTrue(
        dismissSource.contains("closeDeskMenuPanelWithFade()"),
        "Outside-click dismissal should remain wired."
    )
}
```

- [ ] **Step 2: Run the failing test**

Run:

```bash
xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -only-testing:MalDazeTests/ControlPanelPresentationTests/testDeskPetDashboardDismissalUsesCentralInsidePanelGuard
```

Expected: FAIL because no centralized helper exists yet.

- [ ] **Step 3: Implement minimal dismissal helper**

Add a helper in `WindowManager` near the Dashboard dismiss monitor methods:

```swift
private func dashboardPanelContainsMouseLocation(_ mouse: NSPoint) -> Bool {
    guard let panel = deskMenuPanel, panel.isVisible else { return false }
    return panel.frame.contains(mouse)
}
```

Then replace duplicated `panel.frame.contains(mouse)` checks in local/global mouse dismiss monitors with:

```swift
if self.dashboardPanelContainsMouseLocation(mouse) {
    return
}
```

and for the local monitor:

```swift
if self.dashboardPanelContainsMouseLocation(mouse) {
    return event
}
```

- [ ] **Step 4: Preserve outside-click behavior**

Keep the existing desk-pet window guard and close call:

```swift
if let win = self.window, win.frame.contains(mouse) {
    return event
}
self.closeDeskMenuPanelWithFade()
return event
```

For the global monitor, preserve the non-returning version:

```swift
if let win = self.window, win.frame.contains(mouse) {
    return
}
self.closeDeskMenuPanelWithFade()
```

- [ ] **Step 5: Run the test again**

Run the same `xcodebuild test` command.

Expected: PASS.

### Task 3: Verification

**Files:**
- Create: `openspec/changes/fix-assistant-bottom-nav-responsiveness/evidence/verification.md`

- [ ] **Step 1: Run focused tests**

Run:

```bash
xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -only-testing:MalDazeTests/LearningAssistantTests -only-testing:MalDazeTests/ControlPanelPresentationTests
```

Expected: PASS.

- [ ] **Step 2: Manual QA**

In the running app:

1. Click the desk pet to open the Dashboard Panel.
2. Click `今日`, `项目总览`, `日历`, `添加资料`, `资料进度`, `调整计划`, and `设置` once each.
3. Confirm the panel remains visible after each internal click.
4. Confirm selected-state feedback changes immediately.
5. Click outside the panel and confirm it closes.
6. Reopen the panel, press Esc, and confirm it closes.

- [ ] **Step 3: Record evidence**

Create `openspec/changes/fix-assistant-bottom-nav-responsiveness/evidence/verification.md` with:

```markdown
# Verification

- Focused Swift tests: PASS
- Manual QA: PASS
- Notes:
  - Bottom-navigation clicks kept the Dashboard Panel visible.
  - Each tab showed immediate selected feedback.
  - Outside click and Esc still dismissed the panel.
```

## Self-Review

- Spec coverage: Task 1 covers `assistant-panel-ui` bottom navigation responsiveness; Task 2 covers `desk-pet-controls` internal click stability; Task 3 covers verification scenarios.
- Placeholder scan: No TBD/TODO placeholders remain.
- Type consistency: Function and file names match the current Swift source layout.
