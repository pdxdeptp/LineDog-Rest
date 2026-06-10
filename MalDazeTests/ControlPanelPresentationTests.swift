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
            contentSource.contains("DashboardRootView(viewModel: viewModel)"),
            "DeskPetDashboardView should host the dashboard content directly instead of wrapping MenuBarContentView."
        )
        XCTAssertFalse(
            contentSource.contains("MenuBarContentView(viewModel: viewModel)"),
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
            "DeskPetDashboardView should own a visible SwiftUI surface under the transparent titled window chrome."
        )
        XCTAssertTrue(
            rootSource.contains("DashboardPanelSurface.background()"),
            "DeskPetDashboardView should draw a full-bleed panel background instead of a separate transparent titlebar."
        )
        XCTAssertTrue(
            rootSource.contains("trafficLightRowHeight"),
            "DeskPetDashboardView should reserve in-panel space for embedded traffic lights."
        )
        XCTAssertTrue(
            rootSource.contains("ignoresSafeArea(.container, edges: .top)"),
            "DeskPetDashboardView should extend the panel surface under the transparent titlebar."
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

    func testIdlePetWindowOptsOutOfApplicationHide() throws {
        let source = try readProjectSource("MalDaze/WindowManager/WindowManager.swift")
        let installSource = try functionSource(named: "installPetWindowIfNeeded", in: source)

        XCTAssertTrue(
            installSource.contains("win.canHide = false"),
            "The idle desk pet window should remain visible when the application is hidden."
        )
        XCTAssertFalse(
            installSource.contains("dashboardWindow.canHide = false"),
            "The dashboard window should keep default application-hide behavior."
        )
    }

    func testDeskMenuUsesStandardNSWindowNotNSPopover() throws {
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
            source.contains("private final class DeskPetDashboardWindow: NSWindow"),
            "WindowManager should use an NSWindow subclass for the desk pet dashboard."
        )
        XCTAssertTrue(
            source.contains("private var deskMenuWindow: DeskPetDashboardWindow?"),
            "WindowManager should retain the dashboard window for repeat presentation."
        )
        XCTAssertTrue(
            source.contains("private var deskMenuHostingController: NSHostingController<AnyView>?"),
            "WindowManager should retain the SwiftUI host so local dashboard state survives hide/show."
        )
        XCTAssertTrue(
            source.contains("func toggleDashboardWindow()"),
            "WindowManager should expose a unified dashboard toggle entry."
        )
        XCTAssertTrue(
            source.contains("makeDeskMenuWindowIfNeeded"),
            "WindowManager should create or reuse the desk pet dashboard through a window helper."
        )
    }

    func testDeskPetDashboardWindowChromeAndLifecycleAreConfigured() throws {
        let source = try readProjectSource("MalDaze/WindowManager/WindowManager.swift")
        let chromeSource = try functionSource(named: "configureDashboardWindowChrome", in: source)

        XCTAssertTrue(source.contains("override var canBecomeMain: Bool { true }"))
        XCTAssertTrue(source.contains("static let windowStyleMask: NSWindow.StyleMask"))
        XCTAssertTrue(source.contains(".titled, .closable, .miniaturizable, .resizable, .fullSizeContentView"))
        XCTAssertTrue(chromeSource.contains("titlebarAppearsTransparent = true"))
        XCTAssertTrue(chromeSource.contains("isMovableByWindowBackground = false"))
        XCTAssertTrue(chromeSource.contains("titleVisibility = .hidden"))
        XCTAssertTrue(chromeSource.contains("collectionBehavior = [.managed, .fullScreenNone]"))
        XCTAssertTrue(source.contains("deskPetDashboardWindowIdentifier"))
        XCTAssertTrue(source.contains("dashboardWindow.orderOut(nil)"))
        XCTAssertTrue(source.contains("windowShouldClose"))
        XCTAssertTrue(
            source.contains("safeAreaRegions = []"),
            "Dashboard hosting controller should extend SwiftUI under the transparent titlebar."
        )
        XCTAssertTrue(
            source.contains("sizingOptions = [.intrinsicContentSize]"),
            "Dashboard hosting controller should not push SwiftUI minSize back onto the window frame."
        )
        let bindSource = try functionSource(named: "bindDeskPetMenu", in: source)
        XCTAssertFalse(
            bindSource.contains("makeDeskMenuWindowIfNeeded"),
            "bindDeskPetMenu should not eagerly create the dashboard before first open."
        )
    }

    func testDeskPetLeftClickAndShortcutRouteThroughDashboardToggle() throws {
        let source = try readProjectSource("MalDaze/WindowManager/WindowManager.swift")
        let presentRange = try XCTUnwrap(
            rangeOfFunction(named: "presentDeskMenu", in: source),
            "WindowManager should implement the desk pet presenter entry point."
        )
        let presentSource = String(source[presentRange])
        let shortcutRange = try XCTUnwrap(
            rangeOfFunction(named: "presentDeskMenuFromGlobalShortcut", in: source),
            "WindowManager should implement the global shortcut dashboard entry."
        )
        let shortcutSource = String(source[shortcutRange])

        XCTAssertTrue(
            presentSource.contains("toggleDashboardWindow()"),
            "Desk pet left-click should route through the unified dashboard toggle."
        )
        XCTAssertFalse(
            presentSource.contains("DeskPetDashboardPanelLayout"),
            "Desk pet left-click should not re-anchor the dashboard with the legacy panel layout."
        )
        XCTAssertTrue(
            shortcutSource.contains("toggleDashboardWindow()"),
            "Global shortcut should use the same dashboard toggle entry."
        )
        XCTAssertFalse(
            presentSource.contains("show(relativeTo:"),
            "Desk pet left-click should not use NSPopover.show."
        )
    }

    func testDeskPetDashboardUsesEscAndCmdWDismissOnly() throws {
        let source = try readProjectSource("MalDaze/WindowManager/WindowManager.swift")
        let escMonitorSource = try functionSource(named: "installDashboardEscMonitor", in: source)

        XCTAssertTrue(source.contains("installDashboardEscMonitor()"))
        XCTAssertTrue(source.contains("tearDownDashboardEscMonitor()"))
        XCTAssertFalse(
            source.contains("installDashboardDismissMonitors()"),
            "Dashboard should not install legacy outside-click dismiss monitors."
        )
        XCTAssertFalse(
            escMonitorSource.contains("NSApplication.didResignActiveNotification"),
            "Dashboard should not auto-hide on app deactivation."
        )
        XCTAssertFalse(
            escMonitorSource.contains("addGlobalMonitorForEvents"),
            "Dashboard esc monitor should not use global mouse monitors for dismissal."
        )
        XCTAssertTrue(escMonitorSource.contains("NSEvent.addLocalMonitorForEvents(matching: .keyDown)"))
        XCTAssertTrue(escMonitorSource.contains("event.keyCode == 53"))
        XCTAssertTrue(escMonitorSource.contains("charactersIgnoringModifiers?.lowercased() == \"w\""))
        XCTAssertTrue(escMonitorSource.contains("smartInputPanel == nil"))
    }

    func testRestPresentationDemotesVisibleDashboardBelowOtherApplications() throws {
        let source = try readProjectSource("MalDaze/WindowManager/WindowManager.swift")
        let presentRestSource = try functionSource(
            named: "presentRest",
            in: source,
            after: "final class WindowManager"
        )
        let presentBreakRunSource = try functionSource(
            named: "presentBreakRun",
            in: source,
            after: "final class WindowManager"
        )
        let demoteSource = try functionSource(
            named: "demoteVisibleDashboardBelowOtherApplicationsIfNeeded",
            in: source,
            after: "// MARK: - Dashboard 标准窗口"
        )

        XCTAssertTrue(
            presentRestSource.contains("scheduleDemoteVisibleDashboardBelowOtherApplicationsIfNeeded()"),
            "Fullscreen rest should demote a visible dashboard after bringing the pet overlay forward."
        )
        XCTAssertTrue(
            presentBreakRunSource.contains("scheduleDemoteVisibleDashboardBelowOtherApplicationsIfNeeded()"),
            "Break-run rest should demote a visible dashboard after bringing the pet overlay forward."
        )
        XCTAssertTrue(
            demoteSource.contains("dashboard.order(.below, relativeTo: 0)"),
            "Dashboard demotion should keep the window visible without closing it."
        )
    }

    func testPresentRestAndBreakRunDoNotHideDashboardOnEntry() throws {
        let source = try readProjectSource("MalDaze/WindowManager/WindowManager.swift")
        let presentRestSource = try functionSource(named: "presentRest", in: source)
        let presentBreakRunSource = try functionSource(named: "presentBreakRun", in: source)

        XCTAssertFalse(
            presentRestSource.contains("closeDeskMenuImmediate"),
            "Starting fullscreen rest should not hide the dashboard window."
        )
        XCTAssertFalse(
            presentBreakRunSource.contains("closeDeskMenuImmediate"),
            "Starting break-run rest should not hide the dashboard window."
        )
    }

    func testMalDazeDefaultsExposesDashboardWindowPersistenceKeys() throws {
        let source = try readProjectSource("MalDaze/MalDazeDefaults.swift")

        XCTAssertTrue(source.contains("static let dashboardWindowOriginX"))
        XCTAssertTrue(source.contains("static let dashboardWindowOriginY"))
        XCTAssertTrue(source.contains("static let dashboardWindowWidth"))
        XCTAssertTrue(source.contains("static let dashboardWindowHeight"))
    }

    func testApplicationShouldHandleReopenFocusesDashboardWithoutToggle() throws {
        let appDelegateSource = try readProjectSource("MalDaze/MalDazeAppDelegate.swift")
        let appViewModelSource = try readProjectSource("MalDaze/AppViewModel.swift")
        let windowManagerSource = try readProjectSource("MalDaze/WindowManager/WindowManager.swift")
        let notificationsSource = try readProjectSource("MalDaze/MalDazeBroadcastNotifications.swift")

        XCTAssertTrue(
            notificationsSource.contains("focusDashboardFromDock"),
            "Broadcast notifications should define a dock-specific dashboard focus channel."
        )
        XCTAssertTrue(
            appDelegateSource.contains("MalDazeBroadcastNotifications.focusDashboardFromDock"),
            "Dock reopen should post a dock-specific dashboard focus notification."
        )
        XCTAssertFalse(
            appDelegateSource.contains("presentDeskPetMenu"),
            "Dock reopen should not reuse the desk pet menu toggle notification."
        )
        XCTAssertTrue(
            appViewModelSource.contains("MalDazeBroadcastNotifications.focusDashboardFromDock"),
            "AppViewModel should observe the dock-specific dashboard focus notification."
        )
        XCTAssertTrue(
            appViewModelSource.contains("windowManager.showOrFocusDashboardFromDock()"),
            "AppViewModel should route dock reopen to a show/focus entry point."
        )
        XCTAssertTrue(
            windowManagerSource.contains("func showOrFocusDashboardFromDock()"),
            "WindowManager should expose a dock-specific show/focus entry point."
        )
        XCTAssertTrue(
            windowManagerSource.contains("dashboard.makeKeyAndOrderFront(nil)"),
            "Dock focus should bring an already-visible dashboard window to the front."
        )
        XCTAssertTrue(
            windowManagerSource.contains("func presentDeskMenu(from stage: PetStageView, anchorRect: NSRect)"),
            "Desk pet left-click should keep its own presenter entry point."
        )
        let presentDeskMenuSource = try functionSource(
            named: "presentDeskMenu",
            in: windowManagerSource,
            after: "// MARK: - Dashboard 标准窗口"
        )
        XCTAssertTrue(
            presentDeskMenuSource.contains("toggleDashboardWindow()"),
            "Desk pet left-click should still toggle the dashboard window."
        )
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
            source.contains("绑定后右下角桌宠可点击 toggle Dashboard 标准窗口")
                && source.contains("全局快捷键：与左键点桌宠相同，toggle Dashboard 标准窗口"),
            "WindowManaging comments should use Dashboard window semantics for the desk pet entry."
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
            preferredSizeSource.contains("MalDazePresentationAnchor.preferredVisibleFrameForAuxiliaryUI()"),
            "dashboardPreferredContentSize should derive the dashboard width from the desk pet screen visibleFrame."
        )
        XCTAssertTrue(
            source.contains("static let safeHorizontalMargin"),
            "dashboardPreferredContentSize should reserve a named horizontal safety margin."
        )
        XCTAssertTrue(
            preferredSizeSource.contains("DashboardLayout.preferredContentSize")
                && preferredSizeSource.contains("screenVisibleFrame:"),
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
            source.contains("let width = min(layoutWidth * panelWidthScale, visibleFrame.width)"),
            "The sizing helper should keep the shell near full width while clamping it to the visible screen width."
        )
    }

    func testDeskPetDashboardPreferredSizeUsesPetAnchoredVisibleFrame() throws {
        let windowManagerSource = try readProjectSource("MalDaze/WindowManager/WindowManager.swift")
        let dashboardSource = try readProjectSource("MalDaze/DashboardRootView.swift")
        let frameRange = try XCTUnwrap(
            rangeOfFunction(named: "resolvedDashboardWindowFrame", in: windowManagerSource),
            "WindowManager should calculate dashboard window frame through a testable helper."
        )
        let frameSource = String(windowManagerSource[frameRange])

        XCTAssertTrue(
            frameSource.contains("dashboardDefaultVisibleFrame()"),
            "WindowManager should center the dashboard on the desk pet screen when no persistence exists."
        )
        XCTAssertTrue(
            frameSource.contains("MalDazePresentationAnchor.visibleFrameContainingScreenRect(storedFrame)"),
            "Persisted dashboard frames should clamp against the screen that already contains them."
        )
        XCTAssertTrue(
            dashboardSource.contains("MalDazePresentationAnchor.preferredVisibleFrameForAuxiliaryUI()"),
            "Dashboard preferred size should follow the desk pet screen, not the mouse-focused display."
        )
        XCTAssertTrue(
            frameSource.contains("MalDazeDefaults.dashboardWindowOriginX"),
            "WindowManager should restore persisted dashboard window origin."
        )
        XCTAssertTrue(
            dashboardSource.contains("static func preferredContentSize(screenVisibleFrame visibleFrame: NSRect?) -> NSSize"),
            "DeskPetDashboardView should expose a screen-aware preferred size helper for WindowManager."
        )
        let dashboardViewRange = try XCTUnwrap(
            rangeOfType(named: "DeskPetDashboardView", in: dashboardSource),
            "DeskPetDashboardView should define preferredContentSize."
        )
        let dashboardViewSource = String(dashboardSource[dashboardViewRange])
        XCTAssertTrue(
            dashboardViewSource.contains("trafficLightRowHeight"),
            "Dashboard window height should include the in-panel traffic light row."
        )
    }

    func testDashboardColumnWidthsKeepSidesFixedWhileMiddleFlexes() {
        let widths = MalDazeDefaults.clampedDashboardColumnWidths(
            left: 345,
            right: 300,
            totalInnerWidth: 1200,
            middleMin: 360,
            chromeWidth: 12
        )
        XCTAssertEqual(widths.left, 345, accuracy: 0.5)
        XCTAssertEqual(widths.right, 300, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(1200 - widths.left - widths.right - 12, 360)
    }

    func testDashboardRootUsesResizableThreeColumnChrome() throws {
        let source = try readProjectSource("MalDaze/DashboardRootView.swift")

        XCTAssertTrue(source.contains("GeometryReader"))
        XCTAssertTrue(source.contains("final class DashboardColumnResizeHandleView"))
        XCTAssertTrue(source.contains("override func mouseDragged(with event: NSEvent)"))
        XCTAssertTrue(source.contains("DashboardWindowDragStrip"))
        XCTAssertTrue(source.contains("performDrag(with:"))
        XCTAssertFalse(
            source.contains("ScrollView([.horizontal, .vertical])"),
            "Dashboard should fill the window instead of pinning a fixed-size scroll document."
        )
        XCTAssertTrue(
            source.contains("maxWidth: .infinity, maxHeight: .infinity"),
            "Middle column should absorb horizontal resize slack."
        )
    }

    func testDashboardResizeHandleUsesWindowStableDragCoordinates() throws {
        let source = try readProjectSource("MalDaze/DashboardRootView.swift")
        let dragCoordinateSource = try functionSource(named: "dragCoordinate", in: source)

        XCTAssertTrue(
            dragCoordinateSource.contains("event.locationInWindow.x"),
            "Column resize drags should use window x coordinates so handle relayout does not feed into the next delta."
        )
        XCTAssertTrue(
            dragCoordinateSource.contains("-event.locationInWindow.y"),
            "Row resize drags should use stable window y coordinates while preserving the flipped local downward-positive drag direction."
        )
        XCTAssertFalse(
            dragCoordinateSource.contains("convert(event.locationInWindow, from: nil)"),
            "Resize drag deltas must not derive from handle-local coordinates because the handle moves during live layout."
        )
    }

    func testDeskPetDashboardWindowLayoutClampsToSmallVisibleFrame() {
        let visibleFrame = NSRect(x: 100, y: 200, width: 760, height: 520)
        let oversized = NSRect(x: 50, y: 50, width: 900, height: 700)

        let frame = DeskPetDashboardWindowLayout.clampedFrame(
            oversized,
            visibleFrame: visibleFrame
        )
        let insetVisibleFrame = visibleFrame.insetBy(
            dx: DeskPetDashboardWindowLayout.margin,
            dy: DeskPetDashboardWindowLayout.margin
        )

        XCTAssertLessThanOrEqual(frame.width, insetVisibleFrame.width)
        XCTAssertLessThanOrEqual(frame.height, insetVisibleFrame.height)
        XCTAssertGreaterThanOrEqual(frame.minX, insetVisibleFrame.minX)
        XCTAssertLessThanOrEqual(frame.maxX, insetVisibleFrame.maxX)
        XCTAssertGreaterThanOrEqual(frame.minY, insetVisibleFrame.minY)
        XCTAssertLessThanOrEqual(frame.maxY, insetVisibleFrame.maxY)
    }

    func testDeskPetDashboardWindowLayoutCentersOnVisibleFrame() {
        let visibleFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)

        let frame = DeskPetDashboardWindowLayout.centeredFrame(visibleFrame: visibleFrame)
        let insetVisibleFrame = visibleFrame.insetBy(
            dx: DeskPetDashboardWindowLayout.margin,
            dy: DeskPetDashboardWindowLayout.margin
        )

        XCTAssertLessThanOrEqual(frame.maxX, insetVisibleFrame.maxX)
        XCTAssertGreaterThanOrEqual(frame.minX, insetVisibleFrame.minX)
        XCTAssertEqual(frame.midX, insetVisibleFrame.midX, accuracy: 1)
        XCTAssertEqual(frame.midY, insetVisibleFrame.midY, accuracy: 1)
    }

    func testWideDashboardShellKeepsRemindersAndControlsColumnsFixedWithLearningPanelColumn() throws {
        throw XCTSkip("Deprecated: fixed-width source assertions were superseded by resizable, persisted dashboard column widths.")
    }

    func testDashboardControlsColumnUsesFourZoneHierarchyWithQuickActionsBeforeSettings() throws {
        let source = try readProjectSource("MalDaze/DashboardRootView.swift")
        let controlsSource = try propertySource(named: "mainControlsColumn", in: source)

        XCTAssertOrdered(
            ["mainPanelHeader", "statusChip", "controlsQuickActions", "controlsSettingsGroups", "controlsUtilityFooter"],
            in: controlsSource,
            "The right controls column should render header/status, quick actions, settings groups, then utility footer."
        )
        XCTAssertTrue(
            source.contains("private var controlsQuickActions: some View"),
            "DashboardRootView should expose the primary everyday actions as controlsQuickActions."
        )
        XCTAssertTrue(
            source.contains("private var controlsSettingsGroups: some View"),
            "DashboardRootView should group lower-frequency settings behind controlsSettingsGroups."
        )
        XCTAssertTrue(
            source.contains("private var controlsUtilityFooter: some View"),
            "DashboardRootView should isolate reset, test, and quit utilities in controlsUtilityFooter."
        )
        XCTAssertTrue(
            source.contains("DashboardControlDisclosureSection"),
            "Dashboard settings groups should use a local disclosure helper so headers only expand or collapse presentation state."
        )
        XCTAssertTrue(
            source.contains("DashboardQuickActionButton"),
            "Primary actions should use a local quick-action helper with SF Symbol labels."
        )
        XCTAssertTrue(
            source.contains("DashboardUtilityButton"),
            "Footer actions should use a local utility-action helper instead of competing with primary controls."
        )
    }

    func testDashboardQuickActionsWireStateAwareExistingViewModelActions() throws {
        let source = try readProjectSource("MalDaze/DashboardRootView.swift")
        let quickActionsSource = try propertySource(named: "controlsQuickActions", in: source)
        let timerSource = try propertySource(named: "dashboardTimerQuickAction", in: source)
        let countdownSource = try propertySource(named: "dashboardCountdownQuickAction", in: source)
        let hydrationSource = try propertySource(named: "dashboardHydrationQuickAction", in: source)
        let catSource = try propertySource(named: "dashboardCatQuickAction", in: source)

        XCTAssertOrdered(
            ["dashboardTimerQuickAction", "dashboardCountdownQuickAction", "dashboardCatQuickAction"],
            in: quickActionsSource,
            "Everyday controls should keep timer, countdown, and cat actions together before settings."
        )
        XCTAssertFalse(
            quickActionsSource.contains("dashboardHydrationQuickAction"),
            "Hydration pause and enable actions should live with hydration settings instead of competing in the quick-action stack."
        )

        XCTAssertTrue(timerSource.contains("viewModel.startManualFocus()"))
        XCTAssertTrue(timerSource.contains("viewModel.stopTimers()"))
        XCTAssertTrue(timerSource.contains("viewModel.resumeTimers()"))
        XCTAssertTrue(timerSource.contains("viewModel.mode == .manual"))
        XCTAssertTrue(timerSource.contains("自动计时由当前模式控制"))
        XCTAssertTrue(timerSource.contains(".disabled("))

        XCTAssertTrue(countdownSource.contains("viewModel.startSevenMinuteReminder()"))
        XCTAssertTrue(countdownSource.contains("viewModel.cancelSevenMinuteReminder()"))
        XCTAssertTrue(countdownSource.contains("viewModel.isSevenMinuteReminderRunning"))

        XCTAssertTrue(hydrationSource.contains("viewModel.setHydrationReminderEnabled(true)"))
        XCTAssertTrue(hydrationSource.contains("viewModel.setHydrationReminderEnabled(false)"))
        XCTAssertTrue(hydrationSource.contains("viewModel.isHydrationReminderEnabled"))

        XCTAssertTrue(catSource.contains("viewModel.startFiveMinuteCatCompanion()"))
        XCTAssertTrue(catSource.contains("viewModel.cancelFiveMinuteCatCompanion()"))
        XCTAssertTrue(catSource.contains("viewModel.isFiveMinuteCatCompanionActive"))
    }

    func testDashboardHydrationActionLivesInsideHydrationSettings() throws {
        let source = try readProjectSource("MalDaze/DashboardRootView.swift")
        let settingsSource = try propertySource(named: "controlsSettingsGroups", in: source)
        let hydrationSource = try propertySource(named: "dashboardHydrationQuickAction", in: source)

        XCTAssertOrdered(
            ["title: \"喝水设置\"", "dashboardHydrationQuickAction", "$hydrationIntervalStored"],
            in: settingsSource,
            "The hydration enable or pause action should be the first control inside hydration settings."
        )
        XCTAssertTrue(hydrationSource.contains("暂停喝水提醒"))
        XCTAssertTrue(hydrationSource.contains("开启喝水提醒"))
        XCTAssertTrue(hydrationSource.contains("viewModel.setHydrationReminderEnabled(true)"))
        XCTAssertTrue(hydrationSource.contains("viewModel.setHydrationReminderEnabled(false)"))
    }

    func testDashboardRightColumnContainsT7SafeEjectSectionUsingExistingControlStyles() throws {
        let source = try readProjectSource("MalDaze/DashboardRootView.swift")
        let settingsSource = try propertySource(named: "controlsSettingsGroups", in: source)

        XCTAssertOrdered(
            ["title: \"桌宠外观\"", "dashboardT7SafeEjectSection", "title: \"喝水设置\""],
            in: settingsSource,
            "The T7 safe-eject section should live in the right-column settings stack before hydration settings."
        )
        XCTAssertTrue(source.contains("DashboardControlDisclosureSection"))
        XCTAssertTrue(source.contains("DashboardQuickActionButton"))
        XCTAssertTrue(source.contains(".tint(SwitchOnTrackTint.paleBlue)"))
        XCTAssertTrue(source.contains("viewModel.isT7AutomaticEjectEnabled"))
        XCTAssertTrue(source.contains("viewModel.setT7AutomaticEjectEnabled"))
        XCTAssertTrue(source.contains("viewModel.t7ScheduleConfiguration"))
        XCTAssertTrue(source.contains("viewModel.updateT7ScheduleConfiguration"))
        XCTAssertTrue(source.contains("viewModel.isT7ManualEjectAvailable"))
        XCTAssertTrue(source.contains("viewModel.t7LatestResultDisplay"))
        let t7Source = try propertySource(named: "dashboardT7SafeEjectSection", in: source)
        XCTAssertFalse(t7Source.localizedCaseInsensitiveContains("force"))
        XCTAssertFalse(t7Source.contains("强制推出"))
    }

    func testDashboardT7SectionStaysPresentationOnly() throws {
        let source = try readProjectSource("MalDaze/DashboardRootView.swift")
        let forbiddenTokens = [
            "T7BundledEjectHelperURLResolver",
            "helperURLResolver",
            "T7EjectProcessRunner",
            "Process(",
            "T7EjectJSONLLogWriter",
            "FileHandle",
            "JSONL",
            "DiskArbitration",
            "DASession",
            "DADisk"
        ]

        for token in forbiddenTokens {
            XCTAssertFalse(
                source.contains(token),
                "DashboardRootView must stay presentation-only and not contain T7 implementation token: \(token)"
            )
        }

        let t7Source = try propertySource(named: "dashboardT7SafeEjectSection", in: source)
        XCTAssertFalse(t7Source.contains("switch viewModel.t7LatestResult"))
        XCTAssertFalse(t7Source.contains("T7EjectResult.message(for:"))
        XCTAssertFalse(t7Source.contains("DateFormatter("))
    }

    func testInterfaceSuccessAccentsUsePaleBlueInsteadOfGreen() throws {
        let accentAsset = try readProjectSource("MalDaze/Assets.xcassets/AccentColor.colorset/Contents.json")
        XCTAssertTrue(accentAsset.contains("\"red\" : \"0.450\""))
        XCTAssertTrue(accentAsset.contains("\"green\" : \"0.720\""))
        XCTAssertTrue(accentAsset.contains("\"blue\" : \"0.980\""))

        for relativePath in ["MalDaze/DashboardRootView.swift"] {
            let source = try readProjectSource(relativePath)
            XCTAssertFalse(
                source.contains(".green") || source.contains("Color.green"),
                "\(relativePath) should use the pale-blue accent color for success and active UI instead of green."
            )
        }
    }

    func testDashboardTimerCommandSOnlyAppliesToManualStartBranch() throws {
        let source = try readProjectSource("MalDaze/DashboardRootView.swift")
        let timerSource = try propertySource(named: "dashboardTimerQuickAction", in: source)

        XCTAssertTrue(
            source.contains("@ViewBuilder\n    private var dashboardTimerQuickAction: some View"),
            "Timer quick action should be a ViewBuilder so keyboard shortcuts can be attached only to the manual-start branch."
        )
        XCTAssertOrdered(
            [
                "if isManualIdle",
                "viewModel.startManualFocus()",
                ".keyboardShortcut(\"s\", modifiers: [.command])",
                "} else if viewModel.showResumeChronoButton",
                "viewModel.resumeTimers()",
                "} else if viewModel.canStopChronoButton",
                "viewModel.stopTimers()"
            ],
            in: timerSource,
            "Command-S must be scoped to the manual-start action and must not attach to stop or resume states."
        )
        XCTAssertFalse(
            timerSource.contains("return DashboardQuickActionButton"),
            "A single returned stateful timer button would attach modifiers, including Command-S, to every timer state."
        )
    }

    func testDashboardStopTimerActionIsNotProminent() throws {
        let source = try readProjectSource("MalDaze/DashboardRootView.swift")
        let timerSource = try propertySource(named: "dashboardTimerQuickAction", in: source)

        let startTitleRange = try XCTUnwrap(timerSource.range(of: "title: \"开始专注\""))
        let startActionRange = try XCTUnwrap(timerSource[startTitleRange.upperBound...].range(of: "viewModel.startManualFocus()"))
        let startActionSource = String(timerSource[startTitleRange.lowerBound..<startActionRange.upperBound])

        let stopTitleRange = try XCTUnwrap(timerSource.range(of: "title: \"停止计时\""))
        let stopActionRange = try XCTUnwrap(timerSource[stopTitleRange.upperBound...].range(of: "viewModel.stopTimers()"))
        let stopActionSource = String(timerSource[stopTitleRange.lowerBound..<stopActionRange.upperBound])

        XCTAssertTrue(
            startActionSource.contains("isProminent: true"),
            "Starting focus should remain the single prominent timer call to action."
        )
        XCTAssertFalse(
            stopActionSource.contains("isProminent: true"),
            "Stopping a timer is a secondary action and should match the other regular quick actions."
        )
    }

    func testDashboardControlHelpersExposeStatefulAccessibility() throws {
        let source = try readProjectSource("MalDaze/DashboardRootView.swift")
        let disclosureSource = try structSource(named: "DashboardControlDisclosureSection", in: source)
        let quickActionSource = try structSource(named: "DashboardQuickActionButton", in: source)

        XCTAssertTrue(
            disclosureSource.contains(".accessibilityValue(Text(isExpanded ? \"已展开\" : \"已折叠\"))"),
            "Disclosure headers should expose their expanded or collapsed state to assistive technologies."
        )
        XCTAssertTrue(
            disclosureSource.contains(".accessibilityHint(Text(isExpanded ? \"折叠此设置组\" : \"展开此设置组\"))"),
            "Disclosure headers should describe the action that activation will perform."
        )
        XCTAssertTrue(
            quickActionSource.contains(".accessibilityValue(Text(subtitle))"),
            "Quick action buttons should expose subtitle text so state and disabled-context copy is readable."
        )
    }

    func testDashboardSettingsAndFooterPreserveExistingBindingsAndUtilities() throws {
        let source = try readProjectSource("MalDaze/DashboardRootView.swift")
        let settingsSource = try propertySource(named: "controlsSettingsGroups", in: source)
        let footerSource = try propertySource(named: "controlsUtilityFooter", in: source)

        XCTAssertTrue(settingsSource.contains("$pomodoroRestMinutesStored"))
        XCTAssertTrue(settingsSource.contains("$pomodoroWorkMinutesStored"))
        XCTAssertTrue(settingsSource.contains("viewModel.syncPomodoroDurationsFromDefaults()"))
        XCTAssertTrue(settingsSource.contains("viewModel.setBreakInterruptStyle(v)"))
        XCTAssertTrue(settingsSource.contains("viewModel.setRestBlocksClicksDuringRest(v)"))
        XCTAssertTrue(settingsSource.contains("viewModel.setRestDoubleClickEndsRest(v)"))
        XCTAssertTrue(settingsSource.contains("$idlePetIconSideSliderLive"))
        XCTAssertTrue(settingsSource.contains("$idlePetAnimationIntensityStored"))
        XCTAssertTrue(settingsSource.contains("$hydrationIntervalStored"))
        XCTAssertTrue(settingsSource.contains("viewModel.setHydrationReminderInterval(hydrationIntervalStored)"))
        XCTAssertTrue(settingsSource.contains("$hydrationQuietHoursEnabled"))
        XCTAssertTrue(settingsSource.contains("hydrationQuietStartMinutes"))
        XCTAssertTrue(settingsSource.contains("hydrationQuietResumeMinutes"))

        XCTAssertTrue(footerSource.contains("viewModel.resetIdlePetPositionFromUserAction()"))
        XCTAssertTrue(footerSource.contains("viewModel.startTestRestNow()"))
        XCTAssertTrue(footerSource.contains("viewModel.testFireHydrationReminder()"))
        XCTAssertTrue(footerSource.contains("viewModel.quitApp()"))
        XCTAssertTrue(footerSource.contains(".keyboardShortcut(\"q\", modifiers: [.command])"))
        XCTAssertTrue(footerSource.contains("restBlockingHint(viewModel.restBlocksClicksDuringRest)"))
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

    func testSettingsDoNotExposeAssistantBackendLazyStartupTradeoff() throws {
        let settingsSource = try readProjectSource("MalDaze/Settings/MalDazeSettingsView.swift")

        XCTAssertFalse(
            settingsSource.contains("@AppStorage(MalDazeDefaults.assistantBackendLazyStartupEnabled)"),
            "Settings should not expose the retired assistant backend lazy startup key."
        )
        XCTAssertFalse(
            settingsSource.contains("省电") && settingsSource.contains("首次打开"),
            "Settings should not explain retired assistant backend lazy startup behavior."
        )
        XCTAssertFalse(
            settingsSource.contains("下次 App 启动") && settingsSource.contains("不会立即启动或停止"),
            "Settings should not keep retired backend startup helper copy."
        )
    }

    func testSwiftAppSourcesDoNotWireRetiredLearningAssistantSurface() throws {
        let dashboardSource = try readProjectSource("MalDaze/DashboardRootView.swift")
        let settingsSource = try readProjectSource("MalDaze/Settings/MalDazeSettingsView.swift")
        let defaultsSource = try readProjectSource("MalDaze/MalDazeDefaults.swift")
        let appDelegateSource = try readProjectSource("MalDaze/MalDazeAppDelegate.swift")
        let projectSource = try readProjectSource("MalDaze.xcodeproj/project.pbxproj")

        let retiredTokensByFile = [
            "DashboardRootView.swift": [
                "LearningAssistantViewModel",
                "AssistantPanelView",
                "assistantViewModel",
                "assistantMinimumColumnWidth",
                "refreshForDashboardOpen()"
            ],
            "MalDazeSettingsView.swift": [
                "backendProvider",
                "backendModel",
                "selectedBackendAPIKey",
                "assistantBackendLazyStartupEnabled",
                "learningAssistantSettingsPane",
                "学习助手"
            ],
            "MalDazeDefaults.swift": [
                "backendLLMProvider",
                "backendLLMModel",
                "backendGeminiAPIKey",
                "backendOpenAIAPIKey",
                "backendDeepSeekAPIKey",
                "assistantBackendLazyStartupEnabled",
                "resolvedAssistantBackendLazyStartupEnabled",
                "resolvedBackendAPIKey"
            ],
            "MalDazeAppDelegate.swift": [
                "BackendProcessManager",
                "AppBackendLifecycleManaging",
                "backendLifecycle",
                "resolvedAssistantBackendLazyStartupEnabled"
            ],
            "project.pbxproj": [
                "LearningAssistant",
                "AssistantPanelView",
                "LearningAssistantViewModel",
                "BackendProcessManager",
                "LearningAssistantTests",
                "BackendProcessManagerLifecycleTests"
            ]
        ]

        let sourcesByFile = [
            "DashboardRootView.swift": dashboardSource,
            "MalDazeSettingsView.swift": settingsSource,
            "MalDazeDefaults.swift": defaultsSource,
            "MalDazeAppDelegate.swift": appDelegateSource,
            "project.pbxproj": projectSource
        ]

        for (file, tokens) in retiredTokensByFile {
            let source = try XCTUnwrap(sourcesByFile[file])
            for token in tokens {
                XCTAssertFalse(
                    source.contains(token),
                    "\(file) should not keep retired Learning Assistant wiring token: \(token)"
                )
            }
        }

        for retainedDashboardToken in [
            "remindersSidebar",
            "mainControlsColumn",
            "dashboardTimerQuickAction",
            "dashboardHydrationQuickAction",
            "viewModel.startSevenMinuteReminder()",
            "viewModel.startFiveMinuteCatCompanion()"
        ] {
            XCTAssertTrue(
                dashboardSource.contains(retainedDashboardToken),
                "Dashboard should preserve retained control token: \(retainedDashboardToken)"
            )
        }

        for retainedSettingsToken in [
            "@AppStorage(MalDazeDefaults.smartInputLLMProvider)",
            "@AppStorage(MalDazeDefaults.smartInputLLMModel)",
            "@AppStorage(MalDazeDefaults.smartInputGeminiAPIKey)",
            "@AppStorage(MalDazeDefaults.smartInputOpenAIAPIKey)",
            "@AppStorage(MalDazeDefaults.smartInputDeepSeekAPIKey)",
            "selectedSmartInputAPIKey",
            "shortcutsSettingsPane",
            "title: \"添加提醒\""
        ] {
            XCTAssertTrue(
                settingsSource.contains(retainedSettingsToken),
                "Settings should preserve retained Smart Reminder or shortcut token: \(retainedSettingsToken)"
            )
        }
    }

    func testMalDazeSettingsUsesCategorizedDetailShell() throws {
        let settingsSource = try readProjectSource("MalDaze/Settings/MalDazeSettingsView.swift")
        let viewSource = try structSource(named: "MalDazeSettingsView", in: settingsSource)

        XCTAssertTrue(settingsSource.contains("private enum SettingsCategory: String, CaseIterable, Identifiable"))
        XCTAssertTrue(settingsSource.contains("private struct SettingsSidebarButton"))
        XCTAssertTrue(settingsSource.contains("private struct SettingsPane"))
        XCTAssertTrue(settingsSource.contains("private struct SettingsGroup"))
        XCTAssertTrue(viewSource.contains("@State private var selectedCategory: SettingsCategory"))
        XCTAssertTrue(viewSource.contains("settingsSidebar"))
        XCTAssertTrue(viewSource.contains("settingsDetailPane"))
        XCTAssertFalse(
            viewSource.contains(".formStyle(.grouped)"),
            "The redesigned settings view should not be only the old raw grouped Form."
        )
    }

    func testMalDazeSettingsAPIKeyRowsExposeStateAndVisibilityControls() throws {
        let settingsSource = try readProjectSource("MalDaze/Settings/MalDazeSettingsView.swift")
        let apiKeyRowSource = try structSource(named: "APIKeySettingRow", in: settingsSource)

        XCTAssertTrue(apiKeyRowSource.contains("visibleLabel"))
        XCTAssertTrue(apiKeyRowSource.contains("isKeyVisible"))
        XCTAssertTrue(apiKeyRowSource.contains("SecureField"))
        XCTAssertTrue(apiKeyRowSource.contains("TextField"))
        XCTAssertTrue(apiKeyRowSource.contains("已保存在本机"))
        XCTAssertTrue(apiKeyRowSource.contains("未填写"))
        XCTAssertTrue(apiKeyRowSource.contains("仅保存在本机 UserDefaults"))
        XCTAssertTrue(apiKeyRowSource.contains("显示 API Key"))
        XCTAssertTrue(apiKeyRowSource.contains("隐藏 API Key"))
        XCTAssertTrue(apiKeyRowSource.contains(".accessibilityLabel"))
    }

    func testMalDazeSettingsRendersOnlySmartInputProviderCardInModelCredentialsCategory() throws {
        let settingsSource = try readProjectSource("MalDaze/Settings/MalDazeSettingsView.swift")
        let modelPaneSource = try propertySource(named: "modelCredentialsSettingsPane", in: settingsSource)
        let cardSource = try structSource(named: "LLMProviderSettingsCard", in: settingsSource)

        XCTAssertTrue(settingsSource.contains("case modelCredentials"))
        XCTAssertTrue(settingsSource.contains("return \"模型与密钥\""))
        XCTAssertEqual(
            modelPaneSource.ranges(of: "LLMProviderSettingsCard(").count,
            1,
            "The dedicated model/key category should render only the retained Smart Input module."
        )
        XCTAssertTrue(modelPaneSource.contains("title: \"智能输入\""))
        XCTAssertTrue(cardSource.contains("LLMProviderCatalog.providerOptions"))
        XCTAssertTrue(cardSource.contains("LLMProviderCatalog.models(for: provider.wrappedValue)"))
        XCTAssertTrue(cardSource.contains("LLMProviderCatalog.defaultModel(for: newProvider)"))
        XCTAssertTrue(cardSource.contains("APIKeySettingRow("))
        XCTAssertTrue(cardSource.contains("仅保存在本机 UserDefaults"))
        XCTAssertTrue(cardSource.contains("SettingsDesignPalette.paleBlueAccent"))
    }

    func testMalDazeSettingsCategoryOrderExcludesLearningAssistant() throws {
        let settingsSource = try readProjectSource("MalDaze/Settings/MalDazeSettingsView.swift")
        let sidebarSource = try propertySource(named: "settingsSidebar", in: settingsSource)

        XCTAssertOrdered(
            ["case modelCredentials", "case shortcuts"],
            in: settingsSource,
            "Settings categories should keep retained credentials and shortcuts."
        )
        XCTAssertFalse(settingsSource.contains("learningAssistant"))
        XCTAssertFalse(settingsSource.contains("学习助手"))
        XCTAssertTrue(settingsSource.contains("var helperCopy: String"))
        XCTAssertTrue(sidebarSource.contains("selectedCategory.helperCopy"))
        XCTAssertFalse(
            sidebarSource.contains("API Key 按当前实现即时保存到本机设置；本页只改善入口、说明与可读性。"),
            "The sidebar footer helper should follow the selected category instead of always showing API-key copy."
        )
    }

    func testModelCredentialsCategoryContainsOnlyLLMProviderModelAndAPIKeyRows() throws {
        let settingsSource = try readProjectSource("MalDaze/Settings/MalDazeSettingsView.swift")
        let modelPaneSource = try propertySource(named: "modelCredentialsSettingsPane", in: settingsSource)

        XCTAssertEqual(
            modelPaneSource.ranges(of: "LLMProviderSettingsCard(").count,
            1,
            "Model credentials should keep only the retained Smart Input card."
        )

        let forbiddenTokens = [
            "ShortcutSettingRow(",
            "添加提醒",
            "学习助手",
            "懒启动学习助手后端",
            "按需启动后端",
            "assistantBackendLazyStartupEnabled"
        ]

        for token in forbiddenTokens {
            XCTAssertFalse(
                modelPaneSource.contains(token),
                "Model credentials should not include cross-category control: \(token)"
            )
        }
    }

    func testLLMProviderSelectorsUseAlignedCompactMenus() throws {
        let settingsSource = try readProjectSource("MalDaze/Settings/MalDazeSettingsView.swift")
        let cardSource = try structSource(named: "LLMProviderSettingsCard", in: settingsSource)

        XCTAssertFalse(
            cardSource.contains(".pickerStyle(.segmented)"),
            "Provider selection should use the same compact popup style as model selection."
        )
        XCTAssertEqual(
            cardSource.ranges(of: ".pickerStyle(.menu)").count,
            2,
            "Provider and model pickers should both use compact menu picker styling."
        )
    }

    func testShortcutsCategoryIncludesSmartInputAddReminderRecorder() throws {
        let settingsSource = try readProjectSource("MalDaze/Settings/MalDazeSettingsView.swift")
        let shortcutsSource = try propertySource(named: "shortcutsSettingsPane", in: settingsSource)

        XCTAssertTrue(shortcutsSource.contains("ShortcutSettingRow("))
        XCTAssertTrue(shortcutsSource.contains("title: \"添加提醒\""))
        XCTAssertTrue(shortcutsSource.contains("displayString: smartShortcutModel.displayString"))
        XCTAssertTrue(shortcutsSource.contains("isRecording: isRecordingSmartShortcut"))
        XCTAssertTrue(shortcutsSource.contains("onRecord: { isRecordingSmartShortcut = true }"))
        XCTAssertTrue(shortcutsSource.contains("let d = SmartReminderInputShortcut.default"))
        XCTAssertTrue(shortcutsSource.contains("smartKeyCode = Int(d.keyCode)"))
        XCTAssertTrue(shortcutsSource.contains("smartModifiersRaw = SmartReminderInputShortcut.defaultModifiersStorageInt"))
        XCTAssertTrue(shortcutsSource.contains("smartKeyLabel = d.keyLabel"))
    }

    func testSettingsDoesNotContainLearningAssistantCategoryOrBackendStartupPane() throws {
        let settingsSource = try readProjectSource("MalDaze/Settings/MalDazeSettingsView.swift")
        let viewSource = try structSource(named: "MalDazeSettingsView", in: settingsSource)

        XCTAssertFalse(viewSource.contains("case .learningAssistant:"))
        XCTAssertFalse(settingsSource.contains("learningAssistantSettingsPane"))
        XCTAssertFalse(settingsSource.contains("按需启动后端"))
        XCTAssertFalse(settingsSource.contains("assistantBackendLazyStartupEnabled"))
    }

    func testMalDazeSettingsSmartInputUsesSharedProvidersAndIndependentStorageHooks() throws {
        let settingsSource = try readProjectSource("MalDaze/Settings/MalDazeSettingsView.swift")
        let defaultsSource = try readProjectSource("MalDaze/MalDazeDefaults.swift")
        let catalogSource = try readProjectSource("MalDaze/SmartReminder/MalDazeGeminiModelCatalog.swift")
        let modelPaneSource = try propertySource(named: "modelCredentialsSettingsPane", in: settingsSource)

        let requiredSettingsTokens = [
            "@AppStorage(MalDazeDefaults.smartInputLLMProvider)",
            "@AppStorage(MalDazeDefaults.smartInputLLMModel)",
            "@AppStorage(MalDazeDefaults.smartInputGeminiAPIKey)",
            "@AppStorage(MalDazeDefaults.smartInputOpenAIAPIKey)",
            "@AppStorage(MalDazeDefaults.smartInputDeepSeekAPIKey)",
            "@AppStorage(MalDazeDefaults.geminiAPIKey)",
            "@AppStorage(MalDazeDefaults.geminiModelId)",
            "selectedSmartInputAPIKey",
            "selectedSmartInputModel"
        ]

        for token in requiredSettingsTokens {
            XCTAssertTrue(settingsSource.contains(token), "Settings should preserve Smart Input storage hook: \(token)")
        }

        XCTAssertTrue(modelPaneSource.contains("provider: $smartInputProvider"))
        XCTAssertTrue(modelPaneSource.contains("model: selectedSmartInputModel"))
        XCTAssertTrue(modelPaneSource.contains("apiKey: selectedSmartInputAPIKey"))
        XCTAssertTrue(catalogSource.contains("enum LLMProviderID: String, CaseIterable"))
        XCTAssertTrue(catalogSource.contains("case gemini"))
        XCTAssertTrue(catalogSource.contains("case openai"))
        XCTAssertTrue(catalogSource.contains("case deepseek"))
        XCTAssertTrue(catalogSource.contains("enum LLMProviderCatalog"))
        XCTAssertTrue(defaultsSource.contains("resolvedSmartInputAPIKey"))
        XCTAssertTrue(defaultsSource.contains("resolvedSmartInputModel"))
    }

    func testMalDazeSettingsShortcutRowsUseReusableKeycapPresentation() throws {
        let settingsSource = try readProjectSource("MalDaze/Settings/MalDazeSettingsView.swift")
        let shortcutRowSource = try structSource(named: "ShortcutSettingRow", in: settingsSource)

        XCTAssertTrue(shortcutRowSource.contains("keycap"))
        XCTAssertTrue(shortcutRowSource.contains("等待按键"))
        XCTAssertTrue(shortcutRowSource.contains("录制"))
        XCTAssertTrue(shortcutRowSource.contains("恢复默认"))
        XCTAssertTrue(shortcutRowSource.contains("shortcutRecorderBusy && !isRecording"))
        XCTAssertTrue(shortcutRowSource.contains("font(.system(.body, design: .monospaced))"))
    }

    func testMalDazeSettingsPreserveStorageHooksAndPanelBlueAccent() throws {
        let settingsSource = try readProjectSource("MalDaze/Settings/MalDazeSettingsView.swift")

        let requiredTokens = [
            "@AppStorage(MalDazeDefaults.smartInputLLMProvider)",
            "@AppStorage(MalDazeDefaults.smartInputLLMModel)",
            "@AppStorage(MalDazeDefaults.smartInputGeminiAPIKey)",
            "@AppStorage(MalDazeDefaults.smartInputOpenAIAPIKey)",
            "@AppStorage(MalDazeDefaults.smartInputDeepSeekAPIKey)",
            "@AppStorage(MalDazeDefaults.geminiAPIKey)",
            "@AppStorage(MalDazeDefaults.geminiModelId)",
            "LLMProviderCatalog.defaultModel(for: newProvider)",
            "LLMProviderCatalog.providerOptions",
            "GlobalShortcutKeyRecorder(",
            "SettingsEscapeKeyMonitor(shortcutRecorderBusy: shortcutRecorderBusy)",
            "NSHostingController(rootView: MalDazeSettingsView())",
            "Color(red: 0.45, green: 0.72, blue: 0.98)"
        ]

        for token in requiredTokens {
            XCTAssertTrue(
                settingsSource.contains(token),
                "Settings redesign should preserve required token: \(token)"
            )
        }
    }

    func testAppDelegateDoesNotStartRetiredAssistantBackend() throws {
        let appDelegateSource = try readProjectSource("MalDaze/MalDazeAppDelegate.swift")

        XCTAssertFalse(appDelegateSource.contains("BackendProcessManager"))
        XCTAssertFalse(appDelegateSource.contains("AppBackendLifecycleManaging"))
        XCTAssertFalse(appDelegateSource.contains("resolvedAssistantBackendLazyStartupEnabled"))
        XCTAssertTrue(appDelegateSource.contains("MalDazeCarbonGlobalHotKeys.start()"))
        XCTAssertTrue(appDelegateSource.contains("MalDazeCarbonGlobalHotKeys.stop()"))
    }

    func testSmartReminderInputPanelUsesVerticalWrappingInput() throws {
        let source = try readProjectSource("MalDaze/SmartReminder/SmartReminderUIPanels.swift")
        let inputContentSource = try smartReminderInputPanelContentSource(from: source)

        XCTAssertTrue(
            inputContentSource.contains("axis: .vertical"),
            "Smart reminder input should use a vertically wrapping SwiftUI input instead of a fixed single-line strip."
        )
        XCTAssertTrue(
            inputContentSource.contains(".lineLimit(3...6")
                || inputContentSource.contains(".lineLimit(2...6")
                || inputContentSource.contains(".lineLimit(3...5"),
            "Smart reminder input should reserve bounded multiline space for long natural-language drafts."
        )
        XCTAssertTrue(
            inputContentSource.contains("SmartReminderInputPanelLayout.inputMinHeight")
                && inputContentSource.contains("SmartReminderInputPanelLayout.inputMaxHeight"),
            "Smart reminder input should bind its multiline field to named bounded height limits."
        )
    }

    func testSmartReminderInputPanelUsesBoundedCaptureCardSizing() throws {
        let source = try readProjectSource("MalDaze/SmartReminder/SmartReminderUIPanels.swift")

        XCTAssertTrue(
            source.contains("static let width: CGFloat"),
            "Smart reminder input panel should declare a named capture-card width constant."
        )
        XCTAssertTrue(
            source.contains("static let inputMinHeight: CGFloat"),
            "Smart reminder input should reserve readable multiline space through a named constant."
        )
        XCTAssertTrue(
            source.contains("static let inputMaxHeight: CGFloat"),
            "Smart reminder input should cap the growing input area through a named constant."
        )
        XCTAssertTrue(
            source.contains("static let verticalPadding: CGFloat")
                && source.contains("static let contentSpacing: CGFloat")
                && source.contains("static let actionRowHeight: CGFloat"),
            "Smart reminder input panel height should reserve named padding, spacing, and action-row budget."
        )
        XCTAssertTrue(
            source.contains("static var height: CGFloat")
                && source.contains("inputMaxHeight")
                && source.contains("verticalPadding * 2")
                && source.contains("contentSpacing")
                && source.contains("actionRowHeight"),
            "Smart reminder input panel height should be derived from input max height plus action-row and spacing budget."
        )
        XCTAssertTrue(
            source.contains("let w = SmartReminderInputPanelLayout.width")
                && source.contains("let h = SmartReminderInputPanelLayout.height"),
            "Smart reminder input panel host sizing should use the capture-card layout constants."
        )
        XCTAssertFalse(
            source.contains("static let height: CGFloat = 166"),
            "Smart reminder input panel height should not remain a fixed visual number disconnected from its content budget."
        )
        XCTAssertFalse(
            source.contains(".frame(width: 400)"),
            "Smart reminder input should not keep the old fixed 400-point single-line TextField width."
        )
        XCTAssertFalse(
            source.contains("let w: CGFloat = 428") && source.contains("let h: CGFloat = 96"),
            "Smart reminder input panel should no longer use the old 428x96 strip dimensions."
        )
    }

    func testSmartReminderInputPanelKeepsCancelAndAddsExplicitSubmitAction() throws {
        let source = try readProjectSource("MalDaze/SmartReminder/SmartReminderUIPanels.swift")
        let inputContentSource = try smartReminderInputPanelContentSource(from: source)
        let cancelButtonSource = try XCTUnwrap(
            buttonActionSource(titled: "取消", in: inputContentSource),
            "Smart reminder input should keep a cancel button."
        )
        let addButtonSource = try XCTUnwrap(
            buttonActionSource(titled: "添加", in: inputContentSource),
            "Smart reminder input should expose an explicit add button."
        )

        XCTAssertTrue(
            cancelButtonSource.contains("onCancel()"),
            "Smart reminder input should keep an explicit cancel action."
        )
        XCTAssertTrue(
            inputContentSource.contains("func submitOnce()"),
            "Smart reminder input should centralize submit handling in a single-submit guard."
        )
        XCTAssertTrue(
            inputContentSource.contains("hasSubmitted")
                && inputContentSource.contains("guard !hasSubmitted else { return }")
                && inputContentSource.contains("onSubmit(draft)"),
            "Smart reminder input should call onSubmit(draft) only after a per-panel-lifecycle single-submit guard passes."
        )
        XCTAssertTrue(
            inputContentSource.contains(".onSubmit { submitOnce() }"),
            "Return submit should route through the same single-submit guard."
        )
        XCTAssertTrue(
            addButtonSource.contains("submitOnce()"),
            "The explicit add action should route through the same single-submit guard."
        )
        XCTAssertFalse(
            addButtonSource.contains("onSubmit(draft)"),
            "The explicit add action should not bypass the single-submit guard."
        )
    }

    func testSmartReminderEntryPointsAndLifecycleRemainWired() throws {
        let panelSource = try readProjectSource("MalDaze/SmartReminder/SmartReminderUIPanels.swift")
        let appSource = try readProjectSource("MalDaze/AppViewModel.swift")
        let windowManagerSource = try readProjectSource("MalDaze/WindowManager/WindowManager.swift")
        let inputContentSource = try smartReminderInputPanelContentSource(from: panelSource)
        let rightClickSource = try functionSource(
            named: "presentSmartReminderInput",
            in: windowManagerSource,
            after: "    func presentSmartReminderInput(\n        anchorRectInScreen"
        )
        let globalShortcutSource = try functionSource(
            named: "presentSmartReminderInputFromGlobalShortcut",
            in: windowManagerSource,
            after: "    func presentSmartReminderInputFromGlobalShortcut(\n        onSubmit"
        )
        let stagePresenterSource = try functionSource(
            named: "presentSmartReminderInput",
            in: windowManagerSource,
            after: "extension WindowManager: PetStageDeskMenuPresenter"
        )
        let appGlobalRange = try XCTUnwrap(
            rangeOfFunction(named: "presentSmartReminderFromGlobalShortcut", in: appSource),
            "AppViewModel should keep the smart reminder global shortcut entry point."
        )
        let appGlobalSource = String(appSource[appGlobalRange])
        let appRightClickRange = try XCTUnwrap(
            rangeOfFunction(named: "userRequestedSmartReminderInput", in: appSource),
            "AppViewModel should keep the right-click smart reminder entry point."
        )
        let appRightClickSource = String(appSource[appRightClickRange])
        let clearDraftSource = try functionSource(
            named: "clearSmartReminderInputDraftIfStillMatchesSubmittedText",
            in: windowManagerSource,
            after: "    func clearSmartReminderInputDraftIfStillMatchesSubmittedText(_ submitted: String) {"
        )
        let dismissMonitorSource = try functionSource(
            named: "installSmartInputDismissMonitors",
            in: windowManagerSource,
            after: "    private func installSmartInputDismissMonitors()"
        )
        let localClickAwaySource = try XCTUnwrap(
            closureSource(
                assignedTo: "smartInputLocalMouseMonitor",
                containing: "NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown)",
                in: dismissMonitorSource
            ),
            "Smart input local click-away monitor should still be installed."
        )
        let globalClickAwaySource = try XCTUnwrap(
            closureSource(
                assignedTo: "smartInputClickAwayMonitor",
                containing: "NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown)",
                in: dismissMonitorSource
            ),
            "Smart input global click-away monitor should still be installed."
        )

        XCTAssertTrue(
            inputContentSource.contains("fieldFocused = true"),
            "Smart reminder input should still focus the text field on open."
        )
        XCTAssertTrue(
            appSource.contains("forName: MalDazeBroadcastNotifications.openSmartReminderInput")
                && appSource.contains("self?.presentSmartReminderFromGlobalShortcut()"),
            "The openSmartReminderInput notification should still route to the smart reminder global shortcut path."
        )
        XCTAssertTrue(
            stagePresenterSource.contains("vm.userRequestedSmartReminderInput(screenAnchor: screenAnchor)"),
            "Desk pet right-click should still route through AppViewModel's smart reminder presenter."
        )
        XCTAssertTrue(
            appRightClickSource.contains("windowManager.presentSmartReminderInput(")
                && appRightClickSource.contains("anchorRectInScreen: screenAnchor"),
            "AppViewModel right-click entry should still call WindowManager.presentSmartReminderInput with the screen anchor."
        )
        XCTAssertTrue(
            appGlobalSource.contains("windowManager.presentSmartReminderInputFromGlobalShortcut("),
            "AppViewModel global shortcut entry should still call WindowManager.presentSmartReminderInputFromGlobalShortcut."
        )
        XCTAssertTrue(
            rightClickSource.contains("Binding<String>")
                && rightClickSource.contains("get: { [weak self] in self?.smartReminderInputDraft ?? \"\" }")
                && rightClickSource.contains("set: { [weak self] newValue in self?.smartReminderInputDraft = newValue }"),
            "WindowManager should keep the draft binding that preserves text after dismissal."
        )
        XCTAssertTrue(
            rightClickSource.contains("teardownSmartInputPanel(invokeUserCancel: true)")
                && inputContentSource.contains(".onExitCommand(perform: onCancel)"),
            "Cancel, Esc, and dismiss paths should continue invoking the cancel lifecycle."
        )
        XCTAssertTrue(
            dismissMonitorSource.contains("smartInputLocalMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown)")
                && dismissMonitorSource.contains("smartInputClickAwayMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown)"),
            "WindowManager should keep both local and global click-away monitors for smart reminder input dismissal."
        )
        XCTAssertTrue(
            localClickAwaySource.contains("!panel.frame.contains(NSEvent.mouseLocation)")
                && localClickAwaySource.contains("teardownSmartInputPanel(invokeUserCancel: true)"),
            "The local click-away monitor should close through the cancel lifecycle only when the click is outside the panel."
        )
        XCTAssertTrue(
            globalClickAwaySource.contains("!panel.frame.contains(NSEvent.mouseLocation)")
                && globalClickAwaySource.contains("teardownSmartInputPanel(invokeUserCancel: true)"),
            "The global click-away monitor should close through the cancel lifecycle only when the click is outside the panel."
        )
        XCTAssertFalse(
            localClickAwaySource.contains("smartReminderInputDraft = \"\""),
            "Local click-away dismissal should not clear the smart reminder draft directly."
        )
        XCTAssertFalse(
            globalClickAwaySource.contains("smartReminderInputDraft = \"\""),
            "Global click-away dismissal should not clear the smart reminder draft directly."
        )
        XCTAssertTrue(
            localClickAwaySource.contains("return event"),
            "The local click-away monitor should continue returning the event after handling outside clicks."
        )
        XCTAssertFalse(
            dismissMonitorSource.contains("smartReminderInputDraft = \"\""),
            "Click-away dismissal should not clear the smart reminder draft directly."
        )
        XCTAssertTrue(
            globalShortcutSource.contains("presentSmartReminderInput(anchorRectInScreen: anchor, onSubmit: onSubmit, onCancel: onCancel)"),
            "The global shortcut path should continue reusing the same input presenter."
        )
        XCTAssertTrue(
            clearDraftSource.contains("if smartReminderInputDraft == submitted")
                && clearDraftSource.contains("smartReminderInputDraft = \"\""),
            "Successful submit should still clear only the matching draft."
        )
    }

    func testSmartReminderPanelTopCenterFrameClampsToVisibleFrame() {
        let visibleFrame = NSRect(x: 0, y: 0, width: 640, height: 360)
        let anchorNearTopRight = NSRect(x: 606, y: 326, width: 28, height: 28)
        let largePanelSize = NSSize(width: 220, height: 96)
        let margin: CGFloat = 10

        let topRightFrame = SmartReminderUIPanels.frameTopCenter(
            anchor: anchorNearTopRight,
            size: largePanelSize,
            visibleFrame: visibleFrame
        )

        XCTAssertLessThanOrEqual(
            topRightFrame.maxX,
            visibleFrame.maxX - margin,
            "Smart reminder input/toast panel should clamp to the visibleFrame right edge so a right-side Dock cannot cover it."
        )
        XCTAssertGreaterThanOrEqual(
            topRightFrame.minX,
            visibleFrame.minX + margin,
            "Smart reminder input/toast panel should keep its left edge inside the visibleFrame margin."
        )
        XCTAssertLessThanOrEqual(
            topRightFrame.maxY,
            visibleFrame.maxY - margin,
            "Smart reminder input/toast panel should clamp vertically when the anchor is near the top of the visibleFrame."
        )
        XCTAssertGreaterThanOrEqual(
            topRightFrame.minY,
            visibleFrame.minY + margin,
            "Smart reminder input/toast panel should keep its bottom edge inside the visibleFrame margin."
        )

        let anchorNearBottom = NSRect(x: 28, y: 2, width: 28, height: 28)
        let bottomFrame = SmartReminderUIPanels.frameTopCenter(
            anchor: anchorNearBottom,
            size: largePanelSize,
            visibleFrame: visibleFrame
        )

        XCTAssertGreaterThanOrEqual(
            bottomFrame.minY,
            visibleFrame.minY + margin,
            "Smart reminder input/toast panel should clamp vertically when the anchor is near the bottom of the visibleFrame."
        )
        XCTAssertLessThanOrEqual(
            bottomFrame.maxY,
            visibleFrame.maxY - margin,
            "Smart reminder input/toast panel should stay below the visibleFrame top edge after bottom-edge placement."
        )
    }

    func testSmartReminderPositioningRuntimeUsesAnchorScreenVisibleFrame() throws {
        let source = try readProjectSource("MalDaze/SmartReminder/SmartReminderUIPanels.swift")
        let positioningSource = try functionSource(
            named: "positionPanelTopCenter",
            in: source,
            after: "    static func positionPanelTopCenter"
        )

        XCTAssertTrue(
            source.contains("static func frameTopCenter(anchor: NSRect, size: NSSize, visibleFrame: NSRect)"),
            "Smart reminder positioning should expose a deterministic helper that accepts an explicit visibleFrame."
        )
        XCTAssertTrue(
            positioningSource.contains("NSScreen.screens"),
            "Runtime smart reminder positioning should resolve the screen containing the anchor."
        )
        XCTAssertTrue(
            positioningSource.contains(".visibleFrame"),
            "Runtime smart reminder positioning should clamp against NSScreen.visibleFrame rather than the raw screen frame."
        )
        XCTAssertTrue(
            positioningSource.contains("frameTopCenter(anchor: anchor, size: size, visibleFrame:"),
            "Runtime smart reminder positioning should delegate frame calculation to the deterministic helper."
        )
        XCTAssertFalse(
            positioningSource.contains("let x = anchor.midX - size.width / 2"),
            "Runtime smart reminder positioning should no longer directly set an unclamped top-center frame."
        )
    }

    func testDeskReminderSidebarCopyDescribesThreeMonthPlanningWindow() throws {
        let source = try readProjectSource("MalDaze/DashboardRootView.swift")

        XCTAssertTrue(
            source.contains("未来三个月"),
            "The desk reminder sidebar copy should describe the new three-month planning window."
        )
        XCTAssertFalse(
            source.contains("七日内"),
            "The desk reminder sidebar copy should no longer claim the visible range is seven days."
        )
        XCTAssertFalse(
            source.contains("当前窗口内无待办"),
            "The empty state should name the three-month reminder window instead of using a generic current-window phrase."
        )
        XCTAssertTrue(
            source.contains("无逾期待办，未来三个月内也无待办"),
            "The empty state should mention both overdue reminders and the future three-month window."
        )
    }

    func testDeskReminderRowRendersNotesUnderTitleOnlyWhenNonEmpty() throws {
        let source = try readProjectSource("MalDaze/DashboardRootView.swift")
        let rowSource = try functionSource(named: "deskReminderRow", in: source)

        XCTAssertTrue(
            rowSource.contains("VStack(alignment: .leading"),
            "The reminder title and notes should share a compact leading text stack."
        )
        XCTAssertOrdered(
            [
                "Text(item.title.isEmpty ? \"（无标题）\" : item.title)",
                "if !item.notesPlain.isEmpty",
                "Text(item.notesPlain)"
            ],
            in: rowSource,
            "Non-empty reminder notes should render directly under the title."
        )
        XCTAssertOrdered(
            [
                "Text(item.notesPlain)",
                ".font(.caption)",
                ".foregroundStyle(.tertiary)",
                ".lineLimit(2)",
                "Text(timeText)",
                "Menu {"
            ],
            in: rowSource,
            "Reminder notes should be compact, tertiary, line-limited detail text, while due-time and action controls remain after the text block."
        )
    }

    func testEventKitDeskSidebarFetchUsesExclusiveEndAfterThreeMonthTargetDate() throws {
        let source = try readProjectSource("MalDaze/Reminders/EventKitRemindersBacking.swift")
        let fetchSource = try functionSource(named: "fetchDeskSidebarReminders", in: source)
        let helperSource = try functionSource(named: "upcomingReminderWindowExclusiveEnd", in: source)

        XCTAssertTrue(
            fetchSource.contains("upcomingReminderWindowExclusiveEnd(startOfToday: startToday, calendar: calWrap)"),
            "fetchDeskSidebarReminders should use the date-inclusive three-month exclusive end helper for its EventKit predicate."
        )
        XCTAssertTrue(
            helperSource.contains("byAdding: SidebarReminderWindowPolicy.forwardComponent")
                && helperSource.contains("value: SidebarReminderWindowPolicy.forwardValue"),
            "The exclusive end helper should first compute the configured three-month target date."
        )
        XCTAssertTrue(
            helperSource.contains("byAdding: .day")
                && helperSource.contains("value: 1"),
            "The EventKit predicate end should be the start of the day after the three-month target date."
        )
        XCTAssertTrue(
            source.contains("private static func upcomingReminderWindowExclusiveEnd"),
            "The fetch window helper should stay private because it exists to support EventKit fetch construction."
        )
        XCTAssertFalse(
            source.contains("static func upcomingReminderWindowEnd"),
            "The old same-day end helper would exclude reminders later on the three-month target date."
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

    private func smartReminderInputPanelContentSource(from source: String) throws -> String {
        let inputContentRange = try XCTUnwrap(
            rangeOfType(named: "SmartReminderInputPanelContent", in: source),
            "SmartReminderUIPanels.swift should define SmartReminderInputPanelContent."
        )
        return String(source[inputContentRange])
    }

    private func buttonActionSource(titled title: String, in source: String) -> String? {
        guard let declarationRange = source.range(of: "Button(\"\(title)\")"),
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
                    return String(source[declarationRange.lowerBound..<source.index(after: cursor)])
                }
            default:
                break
            }
            cursor = source.index(after: cursor)
        }

        return nil
    }

    private func functionSource(named functionName: String, in source: String, after marker: String) throws -> String {
        let markerRange = try XCTUnwrap(
            source.range(of: marker),
            "Expected to find source marker before \(functionName): \(marker)"
        )
        let tail = String(source[markerRange.lowerBound...])
        let functionRange = try XCTUnwrap(
            rangeOfFunction(named: functionName, in: tail),
            "Expected to find function \(functionName) after marker: \(marker)"
        )
        return String(tail[functionRange])
    }

    private func functionSource(named functionName: String, in source: String) throws -> String {
        let functionRange = try XCTUnwrap(
            rangeOfFunction(named: functionName, in: source),
            "Expected to find function \(functionName)."
        )
        return String(source[functionRange])
    }

    private func propertySource(named propertyName: String, in source: String) throws -> String {
        let propertyRange = try XCTUnwrap(
            rangeOfProperty(named: propertyName, in: source),
            "Expected to find computed property \(propertyName)."
        )
        return String(source[propertyRange])
    }

    private func structSource(named typeName: String, in source: String) throws -> String {
        let structRange = try XCTUnwrap(
            rangeOfStruct(named: typeName, in: source),
            "Expected to find struct \(typeName)."
        )
        return String(source[structRange])
    }

    private func XCTAssertOrdered(
        _ needles: [String],
        in source: String,
        _ message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var searchStart = source.startIndex

        for needle in needles {
            guard let range = source[searchStart...].range(of: needle) else {
                XCTFail("\(message) Missing or out-of-order token: \(needle)", file: file, line: line)
                return
            }
            searchStart = range.upperBound
        }
    }

    private func closureSource(assignedTo name: String, containing call: String, in source: String) -> String? {
        guard let assignmentRange = source.range(of: "\(name) = \(call)"),
              let openingBrace = source[assignmentRange.upperBound...].firstIndex(of: "{")
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
                    return String(source[assignmentRange.lowerBound..<source.index(after: cursor)])
                }
            default:
                break
            }
            cursor = source.index(after: cursor)
        }

        return nil
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

    private func rangeOfProperty(named propertyName: String, in source: String) -> Range<String.Index>? {
        let declarationNeedles = [
            "private var \(propertyName): some View",
            "var \(propertyName): some View"
        ]
        guard let declarationRange = declarationNeedles.compactMap({ source.range(of: $0) }).first,
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

    private func rangeOfStruct(named typeName: String, in source: String) -> Range<String.Index>? {
        guard let declarationRange = source.range(of: "struct \(typeName)"),
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
