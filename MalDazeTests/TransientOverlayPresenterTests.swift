import XCTest
@testable import MalDaze

@MainActor
final class TransientOverlayPresenterTests: XCTestCase {
    func testPassivePresenterUsesNonActivatingScreenSaverPanel() throws {
        let source = try readProjectSource("MalDaze/TransientOverlay/MalDazeTransientOverlayPresenter.swift")
        let passiveSource = try functionSource(
            named: "presentPassiveOverlay",
            in: source,
            after: "final class MalDazeTransientOverlayPresenter"
        )
        let geometrySource = try readProjectSource("MalDaze/TransientOverlay/PassiveCenteredOverlayGeometry.swift")

        XCTAssertTrue(geometrySource.contains(".nonactivatingPanel"))
        XCTAssertTrue(geometrySource.contains(".screenSaver"))
        XCTAssertTrue(passiveSource.contains("NSApp.isActive"))
        XCTAssertTrue(passiveSource.contains("orderFrontRegardless()"))
        XCTAssertTrue(passiveSource.contains("scheduleDashboardDemotionIfNeeded"))
        XCTAssertFalse(passiveSource.contains("NSApp.activate(ignoringOtherApps: true)"))
    }

    func testPassivePresenterDemoteGuardSkipsWhenAppWasActive() throws {
        let source = try readProjectSource("MalDaze/TransientOverlay/MalDazeTransientOverlayPresenter.swift")
        let demoteSource = try functionSource(
            named: "scheduleDashboardDemotionIfNeeded",
            in: source,
            after: "final class MalDazeTransientOverlayPresenter"
        )
        let windowManagerSource = try readProjectSource("MalDaze/WindowManager/WindowManager.swift")
        let demoteDashboardSource = try functionSource(
            named: "demoteVisibleDashboardBelowOtherApplicationsIfNeeded",
            in: windowManagerSource,
            after: "// MARK: - Dashboard 标准窗口"
        )

        XCTAssertTrue(demoteSource.contains("demoteVisibleDashboardIfNeeded"))
        XCTAssertTrue(demoteDashboardSource.contains("onlyIfAppWasInactive"))
        XCTAssertTrue(demoteDashboardSource.contains("appWasActiveBeforeOverlay"))
    }

    func testHydrationReminderDelegatesOverlayPresentation() throws {
        let source = try readProjectSource("MalDaze/HydrationReminder/HydrationReminderController.swift")

        XCTAssertTrue(source.contains("overlayPresenter.presentHydrationReminder"))
        XCTAssertTrue(source.contains("overlayPresenter.dismissHydrationReminder"))
        XCTAssertFalse(source.contains("private var reminderWindow"))
        XCTAssertFalse(source.contains("showReminderWindow"))
        XCTAssertFalse(source.contains("orderFrontRegardless()"))
    }

    func testSevenMinuteReminderDelegatesCenterBellPresentation() throws {
        let source = try readProjectSource("MalDaze/SevenMinuteReminder/SevenMinuteReminderController.swift")

        XCTAssertTrue(source.contains("overlayPresenter.presentCenterBell"))
        XCTAssertTrue(source.contains("overlayPresenter.dismissCenterBell"))
        XCTAssertFalse(source.contains("private var reminderWindow"))
        XCTAssertFalse(source.contains("showReminderWindow"))
    }

    func testSmartReminderRoutesThroughTransientOverlayPresenter() throws {
        let source = try readProjectSource("MalDaze/WindowManager/WindowManager.swift")
        let inputSource = try functionSource(
            named: "presentSmartReminderInput",
            in: source,
            after: "final class WindowManager"
        )
        let toastSource = try functionSource(
            named: "showSmartReminderToast",
            in: source,
            after: "final class WindowManager"
        )

        XCTAssertTrue(inputSource.contains("transientOverlayPresenter.presentSmartReminderInput"))
        XCTAssertTrue(inputSource.contains("SmartReminderUIPanels.makeInputContent"))
        XCTAssertTrue(toastSource.contains("transientOverlayPresenter.presentSmartReminderToast"))
        XCTAssertTrue(toastSource.contains("SmartReminderUIPanels.makeToastContent"))
        XCTAssertTrue(inputSource.contains("installSmartInputDismissMonitors()"))
        XCTAssertTrue(source.contains("smartReminderInputDraft"))
        XCTAssertFalse(source.contains("private var smartInputPanel"))
        XCTAssertFalse(source.contains("private var smartToastPanel"))
    }

    func testDismissedSmartInputDelayedFocusDoesNotRevivePanel() {
        var pendingWork: [() -> Void] = []
        let presenter = MalDazeTransientOverlayPresenter(
            dashboardPolicy: .init(demoteVisibleDashboardIfNeeded: { _ in }),
            scheduleFocusWork: { pendingWork.append($0) }
        )
        let content = makeTestOverlayContent(tag: 1)

        presenter.presentSmartReminderInput(
            content: content,
            anchor: NSRect(x: 100, y: 100, width: 20, height: 20)
        )
        XCTAssertTrue(presenter.isSmartReminderInputVisible)
        let staleFocusWork = pendingWork.last
        presenter.dismissSmartReminderInput()
        XCTAssertFalse(presenter.isSmartReminderInputVisible)

        staleFocusWork?()
        XCTAssertFalse(presenter.isSmartReminderInputVisible)
    }

    func testReplacedSmartInputStaleFocusDoesNotReviveFirstPanel() {
        var pendingWork: [() -> Void] = []
        let presenter = MalDazeTransientOverlayPresenter(
            dashboardPolicy: .init(demoteVisibleDashboardIfNeeded: { _ in }),
            scheduleFocusWork: { pendingWork.append($0) }
        )
        let anchor = NSRect(x: 120, y: 120, width: 20, height: 20)

        presenter.presentSmartReminderInput(content: makeTestOverlayContent(tag: 1), anchor: anchor)
        let staleFocusWork = pendingWork.last
        presenter.presentSmartReminderInput(content: makeTestOverlayContent(tag: 2), anchor: anchor)

        staleFocusWork?()
        XCTAssertTrue(presenter.isSmartReminderInputVisible)
    }

    func testScreenObserverStaysUntilAllOverlaysDismissed() {
        let presenter = MalDazeTransientOverlayPresenter(
            dashboardPolicy: .init(demoteVisibleDashboardIfNeeded: { _ in })
        )
        presenter.presentCenterBell(message: "bell", onDismiss: {})
        presenter.presentSmartReminderInput(
            content: makeTestOverlayContent(tag: 3),
            anchor: NSRect(x: 80, y: 80, width: 20, height: 20)
        )
        presenter.dismissCenterBell()
        XCTAssertTrue(presenter.isSmartReminderInputVisible)

        NotificationCenter.default.post(
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        XCTAssertTrue(presenter.isSmartReminderInputVisible)

        presenter.dismissSmartReminderInput()
        XCTAssertFalse(presenter.isSmartReminderInputVisible)
    }

    func testSmartReminderContentBuilderDoesNotConstructPanels() throws {
        let source = try readProjectSource("MalDaze/SmartReminder/SmartReminderUIPanels.swift")
        let makeInputSource = try functionSource(named: "makeInputContent", in: source)
        let makeToastSource = try functionSource(named: "makeToastContent", in: source)

        XCTAssertTrue(makeInputSource.contains("TransientOverlayContent"))
        XCTAssertTrue(makeToastSource.contains("TransientOverlayContent"))
        XCTAssertFalse(makeInputSource.contains("NSPanel("))
        XCTAssertFalse(makeToastSource.contains("NSPanel("))
    }

    func testPresenterRepositionsPassiveAndInteractiveOverlaysOnScreenChange() throws {
        let source = try readProjectSource("MalDaze/TransientOverlay/MalDazeTransientOverlayPresenter.swift")
        let repositionSource = try functionSource(
            named: "repositionAllOverlays",
            in: source,
            after: "final class MalDazeTransientOverlayPresenter"
        )

        XCTAssertTrue(repositionSource.contains("state.reposition()"))
        XCTAssertTrue(repositionSource.contains("InteractiveAnchoredOverlayGeometry.positionPanel"))
        XCTAssertTrue(source.contains("NSApplication.didChangeScreenParametersNotification"))
    }

    private func makeTestOverlayContent(tag: Int) -> TransientOverlayContent {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 120, height: 40))
        view.identifier = NSUserInterfaceItemIdentifier("overlay-\(tag)")
        return TransientOverlayContent(view: view, size: view.frame.size)
    }

    private func readProjectSource(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }

    private func functionSource(
        named functionName: String,
        in source: String,
        after marker: String? = nil
    ) throws -> String {
        let searchSource: String
        if let marker, let markerRange = source.range(of: marker) {
            searchSource = String(source[markerRange.lowerBound...])
        } else {
            searchSource = source
        }
        guard let signatureRange = searchSource.range(of: "func \(functionName)") else {
            throw NSError(domain: "TransientOverlayPresenterTests", code: 1)
        }
        guard let openingBrace = searchSource[signatureRange.lowerBound...].firstIndex(of: "{") else {
            throw NSError(domain: "TransientOverlayPresenterTests", code: 2)
        }

        var depth = 0
        var cursor = openingBrace
        while cursor < searchSource.endIndex {
            switch searchSource[cursor] {
            case "{":
                depth += 1
            case "}":
                depth -= 1
                if depth == 0 {
                    return String(searchSource[signatureRange.lowerBound..<searchSource.index(after: cursor)])
                }
            default:
                break
            }
            cursor = searchSource.index(after: cursor)
        }
        throw NSError(domain: "TransientOverlayPresenterTests", code: 3)
    }
}
