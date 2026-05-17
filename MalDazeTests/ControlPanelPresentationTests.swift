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

    func testControlPanelPreferredContentSizeUsesVisibleScreenWidthWithSafetyMargin() throws {
        let source = try readProjectSource("MalDaze/MenuBarContentView.swift")
        let preferredSizeRange = try XCTUnwrap(
            rangeOfMember(named: "controlPanelPreferredContentSize", in: source),
            "MenuBarContentView should expose a single shared preferred content size for menu bar and desk pet popovers."
        )
        let preferredSizeSource = String(source[preferredSizeRange])

        XCTAssertTrue(
            preferredSizeSource.contains("NSScreen.main?.visibleFrame"),
            "controlPanelPreferredContentSize should derive the wide popover width from the current screen visibleFrame."
        )
        XCTAssertTrue(
            source.contains("static let safeHorizontalMargin"),
            "controlPanelPreferredContentSize should reserve a named horizontal safety margin."
        )
        XCTAssertTrue(
            preferredSizeSource.contains("ControlPanelLayout.preferredContentSize(screenVisibleFrame:"),
            "controlPanelPreferredContentSize should delegate screen-aware sizing to a testable layout helper."
        )
    }

    func testControlPanelLayoutHelperClampsWidthAndProvidesFallback() throws {
        let source = try readProjectSource("MalDaze/MenuBarContentView.swift")

        XCTAssertTrue(
            source.contains("static func preferredContentSize(screenVisibleFrame visibleFrame: NSRect?) -> NSSize"),
            "MenuBarContentView should keep popover sizing in a deterministic helper that accepts an optional visibleFrame."
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

    func testWideControlPanelShellKeepsOuterColumnsFixedAndAssistantAdaptive() throws {
        let source = try readProjectSource("MalDaze/MenuBarContentView.swift")

        XCTAssertTrue(
            source.contains(".frame(width: ControlPanelLayout.remindersColumnWidth"),
            "The reminders sidebar should keep a fixed width in the wide popover shell."
        )
        XCTAssertTrue(
            source.contains(".frame(width: ControlPanelLayout.controlsColumnWidth"),
            "The right controls column should keep a fixed width in the wide popover shell."
        )
        XCTAssertTrue(
            source.contains(".frame(minWidth: ControlPanelLayout.assistantMinimumColumnWidth, maxWidth: .infinity"),
            "AssistantPanelView should receive the remaining adaptive width between the fixed outer columns."
        )
        XCTAssertFalse(
            source.contains(".frame(width: assistantColumnWidth"),
            "AssistantPanelView should no longer be pinned to the old narrow fixed width."
        )
    }

    func testIdlePetIconSideSettingsChangesBroadcastToRunningAppViewModel() throws {
        let notificationSource = try readProjectSource("MalDaze/MalDazeBroadcastNotifications.swift")
        let panelSource = try readProjectSource("MalDaze/MenuBarContentView.swift")
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
            "MenuBarContentView.swift should post \(notificationName) when icon side slider editing completes."
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
