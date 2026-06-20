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
        XCTAssertTrue(toastSource.contains("transientOverlayPresenter.presentSmartReminderToast"))
        XCTAssertTrue(inputSource.contains("installSmartInputDismissMonitors()"))
        XCTAssertTrue(source.contains("smartReminderInputDraft"))
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
