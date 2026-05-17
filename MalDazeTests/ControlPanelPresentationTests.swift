import AppKit
import XCTest
@testable import MalDaze

final class ControlPanelPresentationTests: XCTestCase {
    private let expectedDeskPetRootHelperName = "makeDeskPetDashboardRootView"

    func testMenuBarExtraUsesCompactSettingsMenuInsteadOfWideControlPanel() throws {
        let source = try readProjectSource("MalDaze/MalDazeApp.swift")
        let menuBarContentRange = try XCTUnwrap(
            rangeOfMenuBarExtraContent(in: source),
            "MalDazeApp should define MenuBarExtra content."
        )
        let menuBarContentSource = String(source[menuBarContentRange])

        XCTAssertFalse(
            menuBarContentSource.contains("DashboardRootView(viewModel:"),
            "MenuBarExtra content should not construct the wide desk pet dashboard."
        )
        XCTAssertTrue(
            menuBarContentSource.contains("MenuBarSettingsMenuView()"),
            "MenuBarExtra content should use the compact settings-only menu view."
        )
        XCTAssertTrue(
            source.contains(".menuBarExtraStyle(.window)"),
            "The menu bar extra should keep its existing window menu style."
        )
    }

    func testCompactMenuBarSettingsMenuHasOneSettingsActionPresentingSettingsWindow() throws {
        let appSource = try readProjectSource("MalDaze/MalDazeApp.swift")
        let settingsSource = try readProjectSource("MalDaze/Settings/MalDazeSettingsView.swift")
        let settingsMenuRange = try XCTUnwrap(
            rangeOfType(named: "MenuBarSettingsMenuView", in: appSource),
            "MalDazeApp should declare a compact MenuBarSettingsMenuView."
        )
        let settingsMenuSource = String(appSource[settingsMenuRange])

        XCTAssertEqual(
            settingsMenuSource.ranges(of: "Button(").count,
            1,
            "The compact menu bar settings menu should expose exactly one settings action."
        )
        XCTAssertTrue(
            settingsMenuSource.contains("MalDazeSettingsWindowPresenter.present()"),
            "The compact menu bar settings action should present the existing settings window presenter."
        )
        XCTAssertFalse(
            settingsMenuSource.contains("DashboardRootView(viewModel:"),
            "The compact menu bar settings menu should not embed the wide desk pet dashboard."
        )
        XCTAssertTrue(
            settingsSource.contains("NSHostingController(rootView: MalDazeSettingsView())"),
            "MalDazeSettingsWindowPresenter should continue reusing MalDazeSettingsView."
        )
    }

    func testSharedPopupContentDoesNotInjectDeskPetOnlyPresentationState() throws {
        let source = try readProjectSource("MalDaze/DashboardRootView.swift")
        let forbiddenTokens = [
            "MalDazeDeskMenuPresentation",
            "maldazeDeskMenuPresentation",
            ".deskPetFloatingPanel",
            "if deskMenuPresentation == .deskPetFloatingPanel"
        ]

        for token in forbiddenTokens {
            XCTAssertFalse(
                source.contains(token),
                "DashboardRootView.swift is the dashboard content source and must not contain desk-pet-only presentation token: \(token)"
            )
        }
    }

    func testWindowManagerUsesSingleSharedDeskPetDashboardRootHelper() throws {
        let source = try readProjectSource("MalDaze/WindowManager/WindowManager.swift")

        XCTAssertTrue(
            source.contains("func \(expectedDeskPetRootHelperName)("),
            "WindowManager should define a single helper named \(expectedDeskPetRootHelperName) for constructing the desk pet dashboard root view."
        )
        XCTAssertFalse(
            source.contains(".environment(\\.maldazeDeskMenuPresentation, .deskPetFloatingPanel)"),
            "Desk pet dashboard root construction should not inject desk-pet-only control-panel presentation environment."
        )
    }

    func testWindowManagerDoesNotHostMenuBarContentViewDirectlyForDeskPetDashboard() throws {
        let source = try readProjectSource("MalDaze/WindowManager/WindowManager.swift")

        let inlineCreations = source.ranges(of: "MenuBarContentView(viewModel:")
        XCTAssertTrue(
            inlineCreations.isEmpty,
            "WindowManager should host a dashboard semantic root instead of MenuBarContentView(viewModel:) directly; found \(inlineCreations.count) inline construction(s)."
        )
    }

    func testDeskPetDashboardRootHelperBuildsDashboardSemanticRoot() throws {
        let source = try readProjectSource("MalDaze/WindowManager/WindowManager.swift")
        let helperRange = try XCTUnwrap(
            rangeOfFunction(named: expectedDeskPetRootHelperName, in: source),
            "WindowManager should keep \(expectedDeskPetRootHelperName) as the desk pet dashboard construction point."
        )
        let helperSource = String(source[helperRange])

        XCTAssertTrue(
            helperSource.contains("AnyView(DeskPetDashboardView(viewModel: vm))"),
            "Desk pet left-click and shortcut presentation should use a dashboard-specific root view."
        )

        let contentSource = try readProjectSource("MalDaze/DashboardRootView.swift")
        XCTAssertTrue(
            contentSource.contains("struct DeskPetDashboardView: View"),
            "DashboardRootView.swift should expose a dashboard semantic root for the desk pet panel."
        )
        XCTAssertTrue(
            contentSource.contains("struct DashboardRootView: View"),
            "DashboardRootView.swift should expose the dashboard content view."
        )
        XCTAssertTrue(
            contentSource.contains("DashboardRootView(viewModel: viewModel, assistantViewModel: learningAssistantViewModel)"),
            "DeskPetDashboardView should host the dashboard content directly instead of wrapping MenuBarContentView."
        )
        XCTAssertFalse(
            contentSource.contains("MenuBarContentView(viewModel: viewModel, assistantViewModel: learningAssistantViewModel)"),
            "DeskPetDashboardView should no longer leave a menu-bar-named shell around the dashboard."
        )
    }

    func testDeskPetDashboardRootDrawsVisibleSurfaceInsideTransparentPanel() throws {
        let source = try readProjectSource("MalDaze/DashboardRootView.swift")
        let rootRange = try XCTUnwrap(
            rangeOfType(named: "DeskPetDashboardView", in: source),
            "DeskPetDashboardView should be the desk pet dashboard's semantic root."
        )
        let rootSource = String(source[rootRange])

        XCTAssertTrue(
            rootSource.contains("DashboardPanelSurface"),
            "DeskPetDashboardView should own a visible SwiftUI surface because its NSPanel shell is transparent."
        )
        XCTAssertTrue(
            rootSource.contains(".background {"),
            "DeskPetDashboardView should draw an actual background instead of relying on transparent NSPanel chrome."
        )
        XCTAssertTrue(
            rootSource.contains(".clipShape("),
            "DeskPetDashboardView should clip the dashboard surface so the transparent panel does not expose square corners."
        )
        XCTAssertTrue(
            rootSource.contains(".overlay("),
            "DeskPetDashboardView should draw a boundary that makes the panel edge visible on varied wallpapers."
        )
    }

    func testDeskPetShellDoesNotUseCustomVisualEffectContentChrome() throws {
        let source = try readProjectSource("MalDaze/WindowManager/WindowManager.swift")
        let forbiddenTokens = [
            "NSVisualEffectView(frame:",
            "effectView.material = .popover",
            "effectView.layer?.cornerRadius",
            "effectView.addSubview(host.view)"
        ]

        for token in forbiddenTokens {
            XCTAssertFalse(
                source.contains(token),
                "Desk pet popup must not wrap shared content in desk-pet-specific custom visual-effect content chrome: \(token)"
            )
        }
    }

    func testDeskMenuUsesReusableNSPanelNotNSPopover() throws {
        let source = try readProjectSource("MalDaze/WindowManager/WindowManager.swift")

        XCTAssertFalse(
            source.contains("NSPopover()"),
            "WindowManager should not create NSPopover for the desk pet dashboard path."
        )
        XCTAssertFalse(
            source.contains("popover.show(relativeTo:"),
            "WindowManager should not show the desk pet dashboard with NSPopover.show(relativeTo:of:preferredEdge:)."
        )
        XCTAssertTrue(
            source.contains("private final class DeskPetDashboardPanel: NSPanel"),
            "WindowManager should use an NSPanel subclass for the desk pet dashboard."
        )
        XCTAssertTrue(
            source.contains("private var deskMenuPanel: DeskPetDashboardPanel?"),
            "WindowManager should retain the dashboard panel for repeat presentation."
        )
        XCTAssertTrue(
            source.contains("private var deskMenuHostingController: NSHostingController<AnyView>?"),
            "WindowManager should retain the SwiftUI host so local dashboard state survives hide/show."
        )
        XCTAssertTrue(
            source.contains("makeDeskMenuPanelIfNeeded"),
            "WindowManager should create or reuse the desk pet dashboard through a panel helper."
        )
    }

    func testDeskPetDashboardPanelChromeAndLifecycleAreConfigured() throws {
        let source = try readProjectSource("MalDaze/WindowManager/WindowManager.swift")

        XCTAssertTrue(source.contains("override var canBecomeKey: Bool { true }"))
        XCTAssertTrue(source.contains("panel.backgroundColor = .clear"))
        XCTAssertTrue(source.contains("panel.isOpaque = false"))
        XCTAssertTrue(source.contains("panel.hasShadow = true"))
        XCTAssertTrue(source.contains("panel.isReleasedWhenClosed = false"))
        XCTAssertTrue(source.contains("existing.setFrame(Self.dashboardPanelFrame"))
        XCTAssertTrue(source.contains("panel.orderOut(nil)"))
    }

    func testDeskPetLeftClickAndShortcutRouteThroughDashboardPanelHelper() throws {
        let source = try readProjectSource("MalDaze/WindowManager/WindowManager.swift")
        let presentRange = try XCTUnwrap(
            rangeOfFunction(named: "presentDeskMenu", in: source),
            "WindowManager should implement the desk pet presenter entry point."
        )
        let presentSource = String(source[presentRange])

        XCTAssertTrue(
            presentSource.contains("makeDeskMenuPanelIfNeeded(anchorRectInScreen:"),
            "Desk pet left-click should route through the dashboard panel helper."
        )
        XCTAssertTrue(
            presentSource.contains("panel.isVisible"),
            "Desk pet left-click should toggle an already-visible dashboard panel closed."
        )
        XCTAssertFalse(
            presentSource.contains("show(relativeTo:"),
            "Desk pet left-click should not use NSPopover.show."
        )
    }

    func testDeskPetDashboardOwnsCustomDismissBehavior() throws {
        let source = try readProjectSource("MalDaze/WindowManager/WindowManager.swift")

        XCTAssertTrue(source.contains("installDashboardDismissMonitors()"))
        XCTAssertTrue(source.contains("tearDownDashboardDismissMonitors()"))
        XCTAssertTrue(source.contains("NSEvent.addGlobalMonitorForEvents"))
        XCTAssertTrue(
            source.contains("NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown])"),
            "Dashboard dismissal should include a local mouse monitor so clicks inside the current app but outside the panel close it."
        )
        XCTAssertTrue(source.contains("NSEvent.addLocalMonitorForEvents(matching: .keyDown)"))
        XCTAssertTrue(source.contains("panel.frame.contains(mouse)"))
        XCTAssertTrue(source.contains("win.frame.contains(mouse)"))
        XCTAssertTrue(source.contains("event.keyCode == 53"))
        XCTAssertTrue(source.contains("smartInputPanel == nil"))
        XCTAssertTrue(source.contains("NSApplication.didResignActiveNotification"))
    }

    func testWindowManagingCommentsUseDashboardPanelSemantics() throws {
        let source = try readProjectSource("MalDaze/WindowManager/WindowManager.swift")

        XCTAssertFalse(
            source.contains("弹出与菜单栏相同的 `MenuBarContentView`"),
            "WindowManaging comments should no longer describe the desk pet surface as the same MenuBarContentView used by the menu bar."
        )
        XCTAssertFalse(
            source.contains("弹出 `MenuBarContentView`"),
            "Global shortcut comments should describe the Dashboard Panel, not MenuBarContentView."
        )
        XCTAssertTrue(
            source.contains("绑定后右下角桌宠可点击打开 Dashboard Panel")
                && source.contains("全局快捷键：锚在桌宠上与左键相同，打开 Dashboard Panel"),
            "WindowManaging comments should use Dashboard Panel semantics for the desk pet entry."
        )
    }

    func testDashboardPreferredContentSizeUsesVisibleScreenWidthWithSafetyMargin() throws {
        let source = try readProjectSource("MalDaze/DashboardRootView.swift")
        let preferredSizeRange = try XCTUnwrap(
            rangeOfMember(named: "dashboardPreferredContentSize", in: source),
            "DashboardRootView should expose a screen-aware preferred content size."
        )
        let preferredSizeSource = String(source[preferredSizeRange])

        XCTAssertTrue(
            preferredSizeSource.contains("NSScreen.main?.visibleFrame"),
            "dashboardPreferredContentSize should derive the dashboard width from the current screen visibleFrame."
        )
        XCTAssertTrue(
            source.contains("static let safeHorizontalMargin"),
            "dashboardPreferredContentSize should reserve a named horizontal safety margin."
        )
        XCTAssertTrue(
            preferredSizeSource.contains("DashboardLayout.preferredContentSize(screenVisibleFrame:"),
            "dashboardPreferredContentSize should delegate screen-aware sizing to a testable layout helper."
        )
    }

    func testDashboardLayoutHelperClampsWidthAndProvidesFallback() throws {
        let source = try readProjectSource("MalDaze/DashboardRootView.swift")

        XCTAssertTrue(
            source.contains("static func preferredContentSize(screenVisibleFrame visibleFrame: NSRect?) -> NSSize"),
            "DashboardRootView should keep sizing in a deterministic helper that accepts an optional visibleFrame."
        )
        XCTAssertTrue(
            source.contains("fallbackVisibleFrame"),
            "The sizing helper should provide a reasonable fallback when no screen is available."
        )
        XCTAssertTrue(
            source.contains("min(targetWidth, visibleFrame.width)"),
            "The sizing helper should clamp the preferred width so it never exceeds the visible screen width."
        )
        XCTAssertTrue(
            source.contains("min(max(minimumContentWidth, clampedTargetWidth), visibleFrame.width)"),
            "The sizing helper should keep the shell near full width while clamping it to the visible screen width."
        )
    }

    func testDeskPetDashboardPreferredSizeUsesAnchorScreenVisibleFrame() throws {
        let windowManagerSource = try readProjectSource("MalDaze/WindowManager/WindowManager.swift")
        let dashboardSource = try readProjectSource("MalDaze/DashboardRootView.swift")
        let helperRange = try XCTUnwrap(
            rangeOfFunction(named: "makeDeskMenuPanelIfNeeded", in: windowManagerSource),
            "WindowManager should create or reuse the dashboard panel through a single helper."
        )
        let helperSource = String(windowManagerSource[helperRange])
        let frameRange = try XCTUnwrap(
            rangeOfFunction(named: "dashboardPanelFrame", in: windowManagerSource),
            "WindowManager should calculate dashboard panel frame through a testable helper."
        )
        let frameSource = String(windowManagerSource[frameRange])

        XCTAssertFalse(
            helperSource.contains("MenuBarContentView.controlPanelPreferredContentSize"),
            "Desk pet dashboard sizing should not use the old menu-bar preferred-size shortcut."
        )
        XCTAssertTrue(
            frameSource.contains("DeskPetDashboardPanelLayout.frame(anchorRectInScreen: anchor, visibleFrame: visibleFrame)"),
            "WindowManager should delegate dashboard frame geometry to the testable panel layout helper."
        )
        XCTAssertTrue(
            windowManagerSource.contains("DeskPetDashboardView.preferredContentSize(screenVisibleFrame: visibleFrame)"),
            "Dashboard panel preferred size should be derived from the visibleFrame of the screen containing the anchor."
        )
        XCTAssertTrue(
            dashboardSource.contains("static func preferredContentSize(screenVisibleFrame visibleFrame: NSRect?) -> NSSize"),
            "DeskPetDashboardView should expose a screen-aware preferred size helper for WindowManager."
        )
    }

    func testDeskPetDashboardPanelLayoutClampsToSmallVisibleFrame() {
        let visibleFrame = NSRect(x: 100, y: 200, width: 760, height: 520)
        let anchor = NSRect(x: 420, y: 230, width: 80, height: 80)

        let frame = DeskPetDashboardPanelLayout.frame(
            anchorRectInScreen: anchor,
            visibleFrame: visibleFrame
        )
        let insetVisibleFrame = visibleFrame.insetBy(
            dx: DeskPetDashboardPanelLayout.margin,
            dy: DeskPetDashboardPanelLayout.margin
        )

        XCTAssertLessThanOrEqual(frame.width, insetVisibleFrame.width)
        XCTAssertLessThanOrEqual(frame.height, insetVisibleFrame.height)
        XCTAssertGreaterThanOrEqual(frame.minX, insetVisibleFrame.minX)
        XCTAssertLessThanOrEqual(frame.maxX, insetVisibleFrame.maxX)
        XCTAssertGreaterThanOrEqual(frame.minY, insetVisibleFrame.minY)
        XCTAssertLessThanOrEqual(frame.maxY, insetVisibleFrame.maxY)
    }

    func testDeskPetDashboardPanelLayoutClampsNearRightEdgeAndFallsBelowWhenNoRoomAbove() {
        let visibleFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let anchor = NSRect(x: 1370, y: 820, width: 56, height: 56)

        let frame = DeskPetDashboardPanelLayout.frame(
            anchorRectInScreen: anchor,
            visibleFrame: visibleFrame
        )
        let insetVisibleFrame = visibleFrame.insetBy(
            dx: DeskPetDashboardPanelLayout.margin,
            dy: DeskPetDashboardPanelLayout.margin
        )

        XCTAssertLessThanOrEqual(frame.maxX, insetVisibleFrame.maxX)
        XCTAssertGreaterThanOrEqual(frame.minX, insetVisibleFrame.minX)
        XCTAssertLessThan(frame.maxY, anchor.minY)
        XCTAssertGreaterThanOrEqual(frame.minY, insetVisibleFrame.minY)
    }

    func testWideDashboardShellKeepsOuterColumnsFixedAndAssistantAdaptive() throws {
        let source = try readProjectSource("MalDaze/DashboardRootView.swift")

        XCTAssertTrue(
            source.contains(".frame(width: DashboardLayout.remindersColumnWidth"),
            "The reminders sidebar should keep a fixed width in the wide dashboard shell."
        )
        XCTAssertTrue(
            source.contains(".frame(width: DashboardLayout.controlsColumnWidth"),
            "The right controls column should keep a fixed width in the wide dashboard shell."
        )
        XCTAssertTrue(
            source.contains(".frame(minWidth: DashboardLayout.assistantMinimumColumnWidth, maxWidth: .infinity"),
            "AssistantPanelView should receive the remaining adaptive width between the fixed outer columns."
        )
        XCTAssertFalse(
            source.contains(".frame(width: assistantColumnWidth"),
            "AssistantPanelView should no longer be pinned to the old narrow fixed width."
        )
    }

    func testIdlePetIconSideSettingsChangesBroadcastToRunningAppViewModel() throws {
        let notificationSource = try readProjectSource("MalDaze/MalDazeBroadcastNotifications.swift")
        let panelSource = try readProjectSource("MalDaze/DashboardRootView.swift")
        let settingsSource = try readProjectSource("MalDaze/Settings/MalDazeSettingsView.swift")
        let appViewModelSource = try readProjectSource("MalDaze/AppViewModel.swift")
        let notificationName = "idlePetIconSidePointsChanged"

        XCTAssertTrue(
            notificationSource.contains("static let \(notificationName)")
                && notificationSource.contains("Notification.Name(\"com.maldaze.\(notificationName)\")"),
            "MalDazeBroadcastNotifications.swift should define \(notificationName) as the shared notification for live desk pet icon-size changes."
        )

        XCTAssertTrue(
            panelSource.contains("MalDazeBroadcastNotifications.\(notificationName)")
                && panelSource.contains("idlePetIconSideSliderLive")
                && panelSource.contains("Slider("),
            "DashboardRootView.swift should post \(notificationName) when icon side slider editing completes."
        )

        XCTAssertFalse(
            settingsSource.contains("idlePetIconSideStored"),
            "MalDazeSettingsView.swift should no longer duplicate idle pet icon side storage in Settings."
        )

        guard let observerRange = appViewModelSource.range(of: "forName: MalDazeBroadcastNotifications.\(notificationName)") else {
            XCTFail("AppViewModel.swift should observe \(notificationName).")
            return
        }

        XCTAssertTrue(
            appViewModelSource[observerRange.upperBound...].contains("applyIdlePetIconSideFromUserDefaults()"),
            "AppViewModel.swift should apply the new idle pet icon side from UserDefaults when \(notificationName) is observed."
        )
    }

    func testSettingsExposeAssistantBackendLazyStartupTradeoff() throws {
        let settingsSource = try readProjectSource("MalDaze/Settings/MalDazeSettingsView.swift")

        XCTAssertTrue(
            settingsSource.contains("@AppStorage(MalDazeDefaults.assistantBackendLazyStartupEnabled)"),
            "Settings should expose the persistent assistant backend lazy startup key."
        )
        XCTAssertTrue(
            settingsSource.contains("省电") && settingsSource.contains("首次打开"),
            "Settings should explain that lazy startup saves energy while the first assistant open may wait for backend startup."
        )
        XCTAssertTrue(
            settingsSource.contains("下次 App 启动") && settingsSource.contains("不会立即启动或停止"),
            "Settings should clarify that the lazy startup switch changes the next app-launch strategy and does not immediately start or stop an existing backend."
        )
    }

    func testAppDelegateStartupModeUsesInjectedUserDefaults() throws {
        let appDelegateSource = try readProjectSource("MalDaze/MalDazeAppDelegate.swift")

        XCTAssertTrue(
            appDelegateSource.contains("private let userDefaults: UserDefaults"),
            "MalDazeAppDelegate should keep an injectable UserDefaults store so tests do not mutate UserDefaults.standard."
        )
        XCTAssertTrue(
            appDelegateSource.contains("resolvedAssistantBackendLazyStartupEnabled(defaults: userDefaults)"),
            "MalDazeAppDelegate should resolve assistant backend startup mode from its injected UserDefaults store."
        )
    }

    private func readProjectSource(_ relativePath: String) throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let repositoryRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = repositoryRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }

    private func rangeOfFunction(named functionName: String, in source: String) -> Range<String.Index>? {
        guard let declarationRange = source.range(of: "func \(functionName)("),
              let openingBrace = source[declarationRange.upperBound...].firstIndex(of: "{")
        else { return nil }

        var depth = 0
        var cursor = openingBrace
        while cursor < source.endIndex {
            switch source[cursor] {
            case "{":
                depth += 1
            case "}":
                depth -= 1
                if depth == 0 {
                    return declarationRange.lowerBound..<source.index(after: cursor)
                }
            default:
                break
            }
            cursor = source.index(after: cursor)
        }

        return nil
    }

    private func rangeOfMenuBarExtraContent(in source: String) -> Range<String.Index>? {
        guard let menuBarRange = source.range(of: "MenuBarExtra {"),
              let labelRange = source[menuBarRange.upperBound...].range(of: "} label:")
        else { return nil }

        return menuBarRange.upperBound..<labelRange.lowerBound
    }

    private func rangeOfMember(named memberName: String, in source: String) -> Range<String.Index>? {
        guard let declarationRange = source.range(of: "static var \(memberName):"),
              let openingBrace = source[declarationRange.upperBound...].firstIndex(of: "{")
        else { return nil }

        var depth = 0
        var cursor = openingBrace
        while cursor < source.endIndex {
            switch source[cursor] {
            case "{":
                depth += 1
            case "}":
                depth -= 1
                if depth == 0 {
                    return declarationRange.lowerBound..<source.index(after: cursor)
                }
            default:
                break
            }
            cursor = source.index(after: cursor)
        }

        return nil
    }

    private func rangeOfType(named typeName: String, in source: String) -> Range<String.Index>? {
        guard let declarationRange = source.range(of: "struct \(typeName):"),
              let openingBrace = source[declarationRange.upperBound...].firstIndex(of: "{")
        else { return nil }

        var depth = 0
        var cursor = openingBrace
        while cursor < source.endIndex {
            switch source[cursor] {
            case "{":
                depth += 1
            case "}":
                depth -= 1
                if depth == 0 {
                    return declarationRange.lowerBound..<source.index(after: cursor)
                }
            default:
                break
            }
            cursor = source.index(after: cursor)
        }

        return nil
    }
}

private extension String {
    func ranges(of needle: String) -> [Range<String.Index>] {
        var result: [Range<String.Index>] = []
        var searchStart = startIndex

        while searchStart < endIndex,
              let range = self[searchStart...].range(of: needle) {
            result.append(range)
            searchStart = range.upperBound
        }

        return result
    }
}
