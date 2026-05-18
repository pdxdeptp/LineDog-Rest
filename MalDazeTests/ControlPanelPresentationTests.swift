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
