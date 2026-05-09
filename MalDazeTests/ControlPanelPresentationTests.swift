import XCTest

final class ControlPanelPresentationTests: XCTestCase {
    private let expectedDeskPetRootHelperName = "makeDeskPetControlPanelRootView"

    func testSharedPopupContentDoesNotInjectDeskPetOnlyPresentationState() throws {
        let source = try readProjectSource("MalDaze/MenuBarContentView.swift")
        let forbiddenTokens = [
            "MalDazeDeskMenuPresentation",
            "maldazeDeskMenuPresentation",
            ".deskPetFloatingPanel",
            "if deskMenuPresentation == .deskPetFloatingPanel"
        ]

        for token in forbiddenTokens {
            XCTAssertFalse(
                source.contains(token),
                "MenuBarContentView.swift is the shared popup content source and must not contain desk-pet-only presentation token: \(token)"
            )
        }
    }

    func testWindowManagerUsesSingleSharedDeskPetControlPanelRootHelper() throws {
        let source = try readProjectSource("MalDaze/WindowManager/WindowManager.swift")

        XCTAssertTrue(
            source.contains("func \(expectedDeskPetRootHelperName)("),
            "WindowManager should define a single helper named \(expectedDeskPetRootHelperName) for constructing the desk pet control panel root view."
        )
        XCTAssertFalse(
            source.contains(".environment(\\.maldazeDeskMenuPresentation, .deskPetFloatingPanel)"),
            "Desk pet popup root construction should not inject desk-pet-only control-panel presentation environment."
        )
    }

    func testWindowManagerOnlyCreatesMenuBarContentViewInsideDeskPetRootHelper() throws {
        let source = try readProjectSource("MalDaze/WindowManager/WindowManager.swift")
        let helperRange = rangeOfFunction(named: expectedDeskPetRootHelperName, in: source)
        let sourceOutsideHelper: String

        if let helperRange {
            sourceOutsideHelper = String(source[..<helperRange.lowerBound] + source[helperRange.upperBound...])
        } else {
            sourceOutsideHelper = source
        }

        let inlineCreationsOutsideHelper = sourceOutsideHelper.ranges(of: "MenuBarContentView(viewModel:")
        XCTAssertTrue(
            inlineCreationsOutsideHelper.isEmpty,
            "MenuBarContentView(viewModel:) should only be constructed inside \(expectedDeskPetRootHelperName); found \(inlineCreationsOutsideHelper.count) inline construction(s) outside that helper."
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

    func testDeskMenuUsesNSPopoverNotNSPanel() throws {
        let source = try readProjectSource("MalDaze/WindowManager/WindowManager.swift")

        XCTAssertTrue(
            source.contains("NSPopover()"),
            "WindowManager should use NSPopover for the desk pet menu instead of NSPanel."
        )
        XCTAssertFalse(
            source.contains("makeDeskMenuPanelIfNeeded"),
            "WindowManager should not use NSPanel-based creation for the desk pet menu."
        )
        XCTAssertTrue(
            source.contains("popover.show(relativeTo:"),
            "WindowManager should show the desk menu using NSPopover.show(relativeTo:of:preferredEdge:)."
        )
    }

    func testIdlePetIconSideSettingsChangesBroadcastToRunningAppViewModel() throws {
        let notificationSource = try readProjectSource("MalDaze/MalDazeBroadcastNotifications.swift")
        let settingsSource = try readProjectSource("MalDaze/Settings/MalDazeSettingsView.swift")
        let appViewModelSource = try readProjectSource("MalDaze/AppViewModel.swift")
        let notificationName = "idlePetIconSidePointsChanged"

        XCTAssertTrue(
            notificationSource.contains("static let \(notificationName)")
                && notificationSource.contains("Notification.Name(\"com.maldaze.\(notificationName)\")"),
            "MalDazeBroadcastNotifications.swift should define \(notificationName) as the shared notification for live desk pet icon-size changes."
        )

        XCTAssertTrue(
            settingsSource.contains(".onChange(of: idlePetIconSideStored)")
                && settingsSource.contains("NotificationCenter.default.post")
                && settingsSource.contains("MalDazeBroadcastNotifications.\(notificationName)"),
            "MalDazeSettingsView.swift should post \(notificationName) when idlePetIconSideStored changes."
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
