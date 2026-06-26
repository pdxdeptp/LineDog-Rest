import Foundation
import Darwin

struct EnergyWakeupSourceTests {
    func run() throws {
        try testIdleCursorTrackingUsesAdaptiveFarAndNearIntervals()
        try testBreakRunTargetsThirtyHertzAndUsesElapsedSecondsForMovement()
        try testBreakRunShieldResolvesFromPetWindowFrame()
        try testBreakRunHelperPanelsRemainVisibleDuringApplicationHideAndDeactivation()
        try testFullscreenRestUsesWholeSecondTicksAfterApproachCompletes()
        try testExtractedEnergyHelpersExercisePassThroughBounceTurnsAndRestCadence()
        try testFocusTimelineDoesNotUnconditionallyStartLiveTick()
        try testDashboardHideInvokesQuiescence()
        try testDashboardShowInvokesQuiescenceResume()
        try testDashboardPanelsDoNotOwnHermesWatcherLifecycle()
        try testAppViewModelRegistersDashboardQuiescenceConsumers()
        try testManualTimerEngineDoesNotUseQuarterSecondRepeatingTimer()
        try testInterventionControllerDoesNotUseThreeSecondPoll()
    }

    private func testIdleCursorTrackingUsesAdaptiveFarAndNearIntervals() throws {
        let source = try readProjectSource("MalDaze/WindowManager/WindowManager.swift")
        let policy = try typeBody(named: "IdleCursorTrackingPolicy", in: source)

        try expect(
            policy.contains("nearPollingInterval"),
            "WindowManager should name the fast cursor polling interval used only near the pet."
        )
        try expect(
            policy.contains("farPollingInterval"),
            "WindowManager should name a slower far/idle cursor polling interval."
        )
        try expect(
            source.contains("scheduleIdleCursorTracking(after:"),
            "Cursor tracking should be rescheduled at the interval selected by the latest pointer distance."
        )
        try expect(
            source.contains("syncIdleWindowMousePolicy(rescheduleIfNeeded: true)"),
            "Mouse policy sync should immediately apply pass-through state and then adapt the next polling interval."
        )
        try expect(
            !(functionBody(named: "startIdleCursorTracking", in: source)?.contains("withTimeInterval: 0.1, repeats: true") ?? false),
            "Idle cursor tracking must no longer continuously poll at 10 Hz while the pointer is far from a static pet."
        )
        try expect(
            source.contains("IdleCursorTrackingPolicy.ignoresMouseEvents(pointer:")
                && source.contains("IdleCursorTrackingPolicy.pollingInterval(pointer:"),
            "WindowManager should route pass-through and cadence decisions through the testable idle cursor policy."
        )
        try expect(
            source.contains("addLocalMonitorForEvents(matching:"),
            "Idle cursor tracking should use a local mouse monitor while the pet window accepts events."
        )
    }

    private func testBreakRunTargetsThirtyHertzAndUsesElapsedSecondsForMovement() throws {
        let source = try readProjectSource("MalDaze/WindowManager/BreakRunController.swift")
        let policy = try typeBody(named: "BreakRunMotionPolicy", in: source)

        try expect(
            policy.contains("tickInterval: TimeInterval = 1.0 / 20.0"),
            "Break-run movement should target about 20 Hz instead of 60 Hz."
        )
        try expect(
            source.contains("lastTickDate"),
            "Break-run movement should remember the previous tick time."
        )
        try expect(
            source.contains("timeIntervalSince(lastTickDate)"),
            "Break-run movement should derive displacement from elapsed time, not fixed timer ticks."
        )
        try expect(
            source.contains("velocity.x * CGFloat(elapsedSeconds)")
                && source.contains("velocity.y * CGFloat(elapsedSeconds)"),
            "Break-run displacement should multiply velocity by elapsed seconds on both axes."
        )
        try expect(
            !source.contains("tickInterval: TimeInterval = 1.0 / 60.0"),
            "Break-run should not keep the previous 60 Hz movement interval."
        )
        try expect(
            policy.contains("visibleFrame.minX + edgeMargin")
                && policy.contains("visibleFrame.maxX - windowSize.width - edgeMargin")
                && policy.contains("visibleFrame.minY + edgeMargin")
                && policy.contains("visibleFrame.maxY - windowSize.height - edgeMargin"),
            "Break-run movement should clamp and bounce inside the current visibleFrame."
        )
        try expect(
            policy.contains("shouldChooseNewVelocity")
                && policy.contains("randomSample < turnProbability"),
            "Break-run random turn probability should remain explicit and testable."
        )
    }

    private func testBreakRunShieldResolvesFromPetWindowFrame() throws {
        let source = try readProjectSource("MalDaze/WindowManager/WindowManager.swift")
        let resolver = try typeBody(named: "BreakRunShieldScreenResolver", in: source)
        let showShield = try expectFunctionBody(named: "showBreakRunShield", in: source)

        try expect(
            !showShield.contains("NSScreen.main"),
            "Delayed break-run shield must not use NSScreen.main because it can follow focus or pointer screen."
        )
        try expect(
            showShield.contains("BreakRunShieldScreenResolver.screenFrame"),
            "showBreakRunShield should resolve the target display through the pet-window-frame resolver."
        )
        try expect(
            resolver.contains("windowFrame.midX")
                && resolver.contains("windowFrame.midY")
                && resolver.contains(".contains(center)"),
            "Break-run shield screen resolution should use the pet window center as the screen anchor."
        )

        let fixture = """
        import Foundation
        import CoreGraphics

        \(resolver)

        struct FixtureFailure: Error, CustomStringConvertible {
            let description: String
        }

        func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
            guard condition() else { throw FixtureFailure(description: message) }
        }

        let left = CGRect(x: 0, y: 0, width: 500, height: 400)
        let right = CGRect(x: 500, y: 0, width: 500, height: 400)
        let menuBar = CGRect(x: 0, y: 400, width: 500, height: 400)

        try expect(
            BreakRunShieldScreenResolver.screenFrame(
                forWindowFrame: CGRect(x: 640, y: 80, width: 80, height: 80),
                screenFrames: [left, right],
                fallbackFrame: menuBar
            ) == right,
            "pet window center on the right display should select the right display"
        )
        try expect(
            BreakRunShieldScreenResolver.screenFrame(
                forWindowFrame: CGRect(x: 1200, y: 80, width: 80, height: 80),
                screenFrames: [left, right],
                fallbackFrame: menuBar
            ) == menuBar,
            "off-screen pet frame should fall back to the menu-bar screen when available"
        )
        try expect(
            BreakRunShieldScreenResolver.screenFrame(
                forWindowFrame: nil,
                screenFrames: [left, right],
                fallbackFrame: nil
            ) == left,
            "missing pet frame should preserve the first-screen fallback"
        )
        """

        try compileAndRunSwiftFixture(fixture)
    }

    private func testBreakRunHelperPanelsRemainVisibleDuringApplicationHideAndDeactivation() throws {
        let source = try readProjectSource("MalDaze/WindowManager/WindowManager.swift")
        let showShield = try expectFunctionBody(named: "showBreakRunShield", in: source)
        let showCountdown = try expectFunctionBody(named: "showBreakRunCountdownPanel", in: source)

        try expect(
            showShield.contains("panel.hidesOnDeactivate = false"),
            "Delayed break-run shield panel should remain visible when MalDaze deactivates."
        )
        try expect(
            showShield.contains("panel.canHide = false"),
            "Delayed break-run shield panel should opt out of application hide."
        )
        try expect(
            showCountdown.contains("panel.hidesOnDeactivate = false"),
            "Fixed break-run countdown panel should remain visible when MalDaze deactivates."
        )
        try expect(
            showCountdown.contains("panel.canHide = false"),
            "Fixed break-run countdown panel should opt out of application hide."
        )
    }

    private func testFullscreenRestUsesWholeSecondTicksAfterApproachCompletes() throws {
        let source = try readProjectSource("MalDaze/WindowManager/PetStageView.swift")
        let policy = try typeBody(named: "RestVisualTickPolicy", in: source)
        let formatter = try typeBody(named: "RestCountdownFormatter", in: source)

        try expect(
            policy.contains("interactiveTickInterval"),
            "PetStageView should name the interactive visual tick interval for approach/fade movement."
        )
        try expect(
            policy.contains("settledTickInterval: TimeInterval = 1.0"),
            "PetStageView should use a whole-second settled tick once approach visuals are static."
        )
        try expect(
            policy.contains("interval(") && policy.contains("forElapsed elapsed"),
            "PetStageView should choose the next fullscreen-rest visual tick interval from elapsed rest time."
        )
        try expect(
            policy.contains("elapsed < growDuration")
                && policy.contains("elapsed >= total - fadeOutDuration"),
            "Fullscreen rest should stay interactive during approach/fade, but use settled cadence between them."
        )
        try expect(
            !(functionBody(named: "startTickTimer", in: source)?.contains("scheduledTimer(withTimeInterval: 1.0 / 15.0, repeats: true") ?? false),
            "Fullscreen rest must not keep one repeating high-frequency visual timer through the settled portion."
        )
        try expect(
            formatter.contains("Int(floor(remaining))")
                && source.contains("RestCountdownFormatter.string(remaining:"),
            "Fullscreen rest countdown should be formatted through a whole-second helper used by PetStageView."
        )
    }

    private func testFocusTimelineDoesNotUnconditionallyStartLiveTick() throws {
        let source = try readProjectSource("MalDaze/FocusSession/FocusTimelinePresenter.swift")
        try expect(
            source.contains("enum LiveSchedulingPhase"),
            "Focus timeline should model hidden/idle/live scheduling phases."
        )
        try expect(
            source.contains("schedulingPhase == .live"),
            "Live tick scheduling should require the live phase."
        )
        try expect(
            !(source.contains("withTimeInterval: 0.25, repeats: true")),
            "Focus timeline must not keep a 4 Hz repeating live tick."
        )
        try expect(
            source.contains("repeats: false"),
            "Focus timeline live tick should use one-shot scheduling."
        )
    }

    private func testDashboardHideInvokesQuiescence() throws {
        let windowManagerSource = try readProjectSource("MalDaze/WindowManager/WindowManager.swift")
        let hideBody = try expectFunctionBody(named: "hideDashboardWindow", in: windowManagerSource)

        try expect(
            hideBody.contains("dashboardPresentationDidHide()"),
            "hideDashboardWindow should transition dashboard presentation to hidden."
        )
        try expect(
            hideBody.contains("deskPetDashboardDidClose"),
            "hideDashboardWindow should broadcast dashboard close for SwiftUI consumers."
        )
    }

    private func testDashboardShowInvokesQuiescenceResume() throws {
        let windowManagerSource = try readProjectSource("MalDaze/WindowManager/WindowManager.swift")
        let showBody = try expectFunctionBody(named: "showDashboardWindow", in: windowManagerSource)

        try expect(
            showBody.contains("dashboardPresentationDidShow()"),
            "showDashboardWindow should transition dashboard presentation to visible."
        )
    }

    private func testDashboardPanelsDoNotOwnHermesWatcherLifecycle() throws {
        let nutritionSource = try readProjectSource("MalDaze/NutritionToday/NutritionTodayPanelView.swift")
        let learningSource = try readProjectSource("MalDaze/LearningDeskPanel/LearningDeskPanelView.swift")

        try expect(
            !nutritionSource.contains("deskPetDashboardDidClose"),
            "Nutrition panel must not pause Hermes watchers via dashboard close notification."
        )
        try expect(
            !nutritionSource.contains("startWatching()"),
            "Nutrition panel must not own Hermes watcher start lifecycle."
        )
        try expect(
            !nutritionSource.contains("stopWatching()"),
            "Nutrition panel must not own Hermes watcher stop lifecycle."
        )
        try expect(
            !learningSource.contains("deskPetDashboardDidClose"),
            "Learning panel must not pause Hermes watchers via dashboard close notification."
        )
        try expect(
            !learningSource.contains("startWatching()"),
            "Learning panel must not own Hermes watcher start lifecycle."
        )
        try expect(
            !learningSource.contains("stopWatching()"),
            "Learning panel must not own Hermes watcher stop lifecycle."
        )
    }

    private func testAppViewModelRegistersDashboardQuiescenceConsumers() throws {
        let source = try readProjectSource("MalDaze/AppViewModel.swift")

        try expect(
            source.contains("registerDashboardQuiescenceConsumers()"),
            "AppViewModel should centralize dashboard quiescence consumer registration."
        )
        try expect(
            source.contains("nutritionTodayViewModel.pauseDashboardObservation()"),
            "AppViewModel should pause nutrition observation through the coordinator."
        )
        try expect(
            source.contains("nutritionTodayViewModel.resumeDashboardObservation()"),
            "AppViewModel should resume nutrition observation through the coordinator."
        )
        try expect(
            source.contains("learningDeskPanelViewModel.pauseDashboardObservation()"),
            "AppViewModel should pause learning observation through the coordinator."
        )
        try expect(
            source.contains("learningDeskPanelViewModel.resumeDashboardObservation()"),
            "AppViewModel should resume learning observation through the coordinator."
        )
        try expect(
            source.contains("registerConsumer"),
            "AppViewModel should register paired pause/resume dashboard consumers."
        )
    }

    private func testManualTimerEngineDoesNotUseQuarterSecondRepeatingTimer() throws {
        let source = try readProjectSource("MalDaze/TimerEngine/ManualTimerEngine.swift")
        try expect(
            !(source.contains("withTimeInterval: 0.25, repeats: true")),
            "ManualTimerEngine must not use a 4 Hz repeating tick timer."
        )
        try expect(
            source.contains("repeats: false"),
            "ManualTimerEngine should schedule one-shot ticks."
        )
    }

    private func testInterventionControllerDoesNotUseThreeSecondPoll() throws {
        let source = try readProjectSource("MalDaze/InterventionRequest/InterventionRequestController.swift")
        try expect(
            !(source.contains("timeInterval: 3.0, repeats: true")),
            "InterventionRequestController must not keep a 3 second repeating poll timer."
        )
        try expect(
            source.contains("didWakeNotification"),
            "Intervention reconcile should still observe wake notifications."
        )
        try expect(
            source.contains("InterventionRequestFileWatcher"),
            "Intervention reconcile should still use FSEvents file watching."
        )
    }

    private func testExtractedEnergyHelpersExercisePassThroughBounceTurnsAndRestCadence() throws {
        let windowManagerSource = try readProjectSource("MalDaze/WindowManager/WindowManager.swift")
        let breakRunSource = try readProjectSource("MalDaze/WindowManager/BreakRunController.swift")
        let petStageSource = try readProjectSource("MalDaze/WindowManager/PetStageView.swift")
        let fixture = """
        import Foundation
        import CoreGraphics

        \(try typeBody(named: "IdleCursorTrackingPolicy", in: windowManagerSource))
        \(try typeBody(named: "BreakRunMotionPolicy", in: breakRunSource))
        \(try typeBody(named: "RestVisualTickPolicy", in: petStageSource))
        \(try typeBody(named: "RestCountdownFormatter", in: petStageSource))

        struct FixtureFailure: Error, CustomStringConvertible {
            let description: String
        }

        func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
            guard condition() else { throw FixtureFailure(description: message) }
        }

        let petRect = CGRect(x: 100, y: 100, width: 40, height: 40)
        try expect(
            IdleCursorTrackingPolicy.ignoresMouseEvents(pointer: CGPoint(x: 120, y: 120), petScreenRect: petRect) == false,
            "inside pet hit rect should not pass through"
        )
        try expect(
            IdleCursorTrackingPolicy.ignoresMouseEvents(pointer: CGPoint(x: 20, y: 20), petScreenRect: petRect) == true,
            "outside pet hit rect should pass through"
        )
        try expect(
            IdleCursorTrackingPolicy.farPollingInterval > 0.1,
            "far idle cursor interval should be lower wakeup than 10 Hz"
        )
        try expect(
            IdleCursorTrackingPolicy.pollingInterval(pointer: CGPoint(x: 120, y: 120), petScreenRect: petRect)
                == IdleCursorTrackingPolicy.nearPollingInterval,
            "near/inside pointer should use fast sync cadence"
        )
        try expect(
            IdleCursorTrackingPolicy.pollingInterval(pointer: CGPoint(x: -500, y: -500), petScreenRect: petRect)
                == IdleCursorTrackingPolicy.farPollingInterval,
            "far pointer should use low wakeup cadence"
        )

        let visible = CGRect(x: 0, y: 0, width: 320, height: 240)
        let rightBounce = BreakRunMotionPolicy.step(
            origin: CGPoint(x: 260, y: 40),
            windowSize: CGSize(width: 50, height: 50),
            visibleFrame: visible,
            velocity: CGPoint(x: 200, y: 0),
            elapsedSeconds: 1
        )
        try expect(rightBounce.origin.x == 262, "right bounce should clamp to visibleFrame maxX minus window width and edge margin")
        try expect(rightBounce.velocity.x < 0, "right bounce should reverse x velocity")

        let bottomBounce = BreakRunMotionPolicy.step(
            origin: CGPoint(x: 40, y: 6),
            windowSize: CGSize(width: 50, height: 50),
            visibleFrame: visible,
            velocity: CGPoint(x: 0, y: -100),
            elapsedSeconds: 0.5
        )
        try expect(bottomBounce.origin.y == 8, "bottom bounce should clamp to visibleFrame minY plus edge margin")
        try expect(bottomBounce.velocity.y > 0, "bottom bounce should reverse y velocity")
        try expect(
            BreakRunMotionPolicy.shouldChooseNewVelocity(now: Date(timeIntervalSince1970: 5), nextTurnAt: Date(timeIntervalSince1970: 4), randomSample: 0.44),
            "random turn should still happen after turn time when sample is below PawPal probability"
        )
        try expect(
            !BreakRunMotionPolicy.shouldChooseNewVelocity(now: Date(timeIntervalSince1970: 5), nextTurnAt: Date(timeIntervalSince1970: 4), randomSample: 0.45),
            "random turn should preserve strict probability threshold"
        )
        try expect(
            !BreakRunMotionPolicy.shouldChooseNewVelocity(now: Date(timeIntervalSince1970: 3), nextTurnAt: Date(timeIntervalSince1970: 4), randomSample: 0),
            "random turn should not happen before the scheduled turn time"
        )

        try expect(
            RestVisualTickPolicy.interval(forElapsed: 30, total: 180, growDuration: 60, fadeOutDuration: 3)
                == RestVisualTickPolicy.interactiveTickInterval,
            "approach should remain interactive cadence"
        )
        try expect(
            RestVisualTickPolicy.interval(forElapsed: 61, total: 180, growDuration: 60, fadeOutDuration: 3)
                == RestVisualTickPolicy.settledTickInterval,
            "settled rest should drop to whole-second cadence"
        )
        try expect(
            RestVisualTickPolicy.interval(forElapsed: 178, total: 180, growDuration: 60, fadeOutDuration: 3)
                == RestVisualTickPolicy.interactiveTickInterval,
            "fade-out should return to interactive cadence"
        )
        try expect(RestCountdownFormatter.string(remaining: 61.9) == "1:01", "countdown should floor to whole seconds")
        try expect(RestCountdownFormatter.string(remaining: -2) == "0:00", "countdown should clamp negative remaining time")
        """

        try compileAndRunSwiftFixture(fixture)
    }

    private func readProjectSource(_ relativePath: String) throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let repositoryRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = repositoryRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }

    private func typeBody(named typeName: String, in source: String) throws -> String {
        guard let declarationRange = source.range(of: "struct \(typeName)"),
              let openingBrace = source[declarationRange.upperBound...].firstIndex(of: "{")
        else {
            throw EnergyWakeupSourceTestFailure("Expected production helper struct \(typeName) to exist.")
        }

        var depth = 0
        var cursor = openingBrace
        while cursor < source.endIndex {
            switch source[cursor] {
            case "{":
                depth += 1
            case "}":
                depth -= 1
                if depth == 0 {
                    return String(source[declarationRange.lowerBound...cursor])
                }
            default:
                break
            }
            cursor = source.index(after: cursor)
        }
        throw EnergyWakeupSourceTestFailure("Could not parse production helper struct \(typeName).")
    }

    private func functionBody(named functionName: String, in source: String) -> String? {
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
                    return String(source[declarationRange.lowerBound...cursor])
                }
            default:
                break
            }
            cursor = source.index(after: cursor)
        }
        return nil
    }

    private func expectFunctionBody(named functionName: String, in source: String) throws -> String {
        guard let body = functionBody(named: functionName, in: source) else {
            throw EnergyWakeupSourceTestFailure("Expected production function \(functionName) to exist.")
        }
        return body
    }

    private func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else {
            throw EnergyWakeupSourceTestFailure(message)
        }
    }

    private func compileAndRunSwiftFixture(_ source: String) throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let dir = root
            .appendingPathComponent("DerivedData")
            .appendingPathComponent("EnergyWakeupHelperFixtures")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let sourceURL = dir.appendingPathComponent("Fixture.swift")
        let binaryURL = dir.appendingPathComponent("Fixture")
        try source.write(to: sourceURL, atomically: true, encoding: .utf8)
        try runCommand("/usr/bin/xcrun", arguments: ["swiftc", sourceURL.path, "-o", binaryURL.path])
        try runCommand(binaryURL.path, arguments: [])
    }

    private func runCommand(_ executable: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let stdout = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let stderr = String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw EnergyWakeupSourceTestFailure("Command failed: \(executable) \(arguments.joined(separator: " "))\n\(stdout)\(stderr)")
        }
    }
}

private struct EnergyWakeupSourceTestFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

#if ENERGY_WAKEUP_SOURCE_TESTS_STANDALONE
do {
    try EnergyWakeupSourceTests().run()
    print("EnergyWakeupSourceTests passed")
} catch {
    fputs("EnergyWakeupSourceTests failed: \(error)\n", stderr)
    exit(1)
}
#endif
