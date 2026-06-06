import XCTest
@testable import MalDaze

final class T7EjectHelperProjectWiringTests: XCTestCase {
    func testProjectDefinesBundledT7EjectHelperToolTarget() throws {
        let project = try Self.projectFileContents()

        XCTAssertTrue(project.contains("T7EjectHelper"), "Expected a T7EjectHelper target and product reference.")
        XCTAssertTrue(
            project.contains("productType = \"com.apple.product-type.tool\";"),
            "T7EjectHelper must be a command-line tool target."
        )
        XCTAssertTrue(
            project.contains("DiskArbitration.framework in Frameworks"),
            "The helper target must link DiskArbitration.framework."
        )
        XCTAssertTrue(
            project.contains("IOKit.framework in Frameworks"),
            "The helper target must link IOKit.framework."
        )
        XCTAssertTrue(
            project.contains("T7EjectHelper in CopyFiles"),
            "The MalDaze app target must copy the helper executable into the app bundle."
        )
        XCTAssertTrue(
            project.contains("main.swift") && project.contains("T7EjectHelper"),
            "The helper target must include a thin main.swift entry point."
        )
    }

    private static func projectFileContents() throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let projectURL = root
            .appendingPathComponent("MalDaze.xcodeproj")
            .appendingPathComponent("project.pbxproj")
        return try String(contentsOf: projectURL, encoding: .utf8)
    }
}

final class T7EjectResultTests: XCTestCase {
    func testSuccessResultRoundTripsRequiredDiagnosticFields() throws {
        let result = T7EjectResult(
            status: .success,
            reason: nil,
            action: .safeEject,
            wholeDisk: "disk4",
            apfsContainer: "disk5",
            volumes: ["Storage", "T7 Shield"],
            timeMachineWasRunning: true,
            timeMachineStopped: true,
            remainingMountedVolumes: [],
            dissenterStatus: nil,
            dissenterMessage: nil,
            startedAt: try Self.date("2026-06-06T00:00:00Z"),
            endedAt: try Self.date("2026-06-06T00:00:03Z"),
            message: T7EjectResult.message(for: .success, reason: nil)
        )

        let payload = try Self.roundTrip(result)

        XCTAssertEqual(payload["status"] as? String, "success")
        XCTAssertNil(payload["reason"] as? String)
        XCTAssertEqual(payload["action"] as? String, "safe_eject")
        XCTAssertEqual(payload["wholeDisk"] as? String, "disk4")
        XCTAssertEqual(payload["apfsContainer"] as? String, "disk5")
        XCTAssertEqual(payload["volumes"] as? [String], ["Storage", "T7 Shield"])
        XCTAssertEqual(payload["timeMachineWasRunning"] as? Bool, true)
        XCTAssertEqual(payload["timeMachineStopped"] as? Bool, true)
        XCTAssertEqual(payload["remainingMountedVolumes"] as? [String], [])
        XCTAssertEqual(payload["message"] as? String, "T7 已安全推出。")
    }

    func testFailedDiskBusyResultRoundTripsDiagnosticsAndChineseMessage() throws {
        let result = T7EjectResult(
            status: .failed,
            reason: .diskBusy,
            action: .safeEject,
            wholeDisk: "disk4",
            apfsContainer: "disk5",
            volumes: ["Storage"],
            timeMachineWasRunning: false,
            timeMachineStopped: false,
            remainingMountedVolumes: ["Storage"],
            dissenterStatus: 49153,
            dissenterMessage: "Resource busy",
            startedAt: try Self.date("2026-06-06T00:01:00Z"),
            endedAt: try Self.date("2026-06-06T00:01:02Z"),
            message: T7EjectResult.message(for: .failed, reason: .diskBusy)
        )

        let payload = try Self.roundTrip(result)

        XCTAssertEqual(payload["status"] as? String, "failed")
        XCTAssertEqual(payload["reason"] as? String, "disk_busy")
        XCTAssertEqual(payload["remainingMountedVolumes"] as? [String], ["Storage"])
        XCTAssertEqual(payload["dissenterStatus"] as? Int, 49153)
        XCTAssertEqual(payload["dissenterMessage"] as? String, "Resource busy")
        XCTAssertEqual(payload["message"] as? String, "T7 正在被占用，未强制推出。")
    }

    func testIdleResultsRoundTripNotConnectedAndAlreadyUnmountedShapes() throws {
        let cases: [(T7EjectReason, String?, [String], String)] = [
            (.idleNotConnected, nil, [], "未发现已连接的 T7。"),
            (.idleAlreadyUnmounted, "disk4", ["Storage", "T7 Shield"], "T7 已经处于未挂载状态。"),
        ]

        for (reason, wholeDisk, volumes, message) in cases {
            let result = T7EjectResult(
                status: .idle,
                reason: reason,
                action: .safeEject,
                wholeDisk: wholeDisk,
                apfsContainer: wholeDisk == nil ? nil : "disk5",
                volumes: volumes,
                timeMachineWasRunning: false,
                timeMachineStopped: false,
                remainingMountedVolumes: [],
                dissenterStatus: nil,
                dissenterMessage: nil,
                startedAt: try Self.date("2026-06-06T00:02:00Z"),
                endedAt: try Self.date("2026-06-06T00:02:00Z"),
                message: T7EjectResult.message(for: .idle, reason: reason)
            )

            let payload = try Self.roundTrip(result)

            XCTAssertEqual(payload["status"] as? String, "idle")
            XCTAssertEqual(payload["reason"] as? String, reason.rawValue)
            XCTAssertEqual(payload["wholeDisk"] as? String, wholeDisk)
            XCTAssertEqual(payload["volumes"] as? [String], volumes)
            XCTAssertEqual(payload["message"] as? String, message)
        }
    }

    func testStdoutJSONFormattingProducesSingleDecodableResultObject() throws {
        let result = T7EjectResult(
            status: .idle,
            reason: .idleNotConnected,
            action: .safeEject,
            wholeDisk: nil,
            apfsContainer: nil,
            volumes: [],
            timeMachineWasRunning: false,
            timeMachineStopped: false,
            remainingMountedVolumes: [],
            dissenterStatus: nil,
            dissenterMessage: nil,
            startedAt: try Self.date("2026-06-06T00:03:00Z"),
            endedAt: try Self.date("2026-06-06T00:03:00Z"),
            message: T7EjectResult.message(for: .idle, reason: .idleNotConnected)
        )

        let stdout = try result.stdoutJSONString()

        XCTAssertTrue(stdout.hasPrefix("{"))
        XCTAssertTrue(stdout.hasSuffix("}"))
        XCTAssertFalse(stdout.contains("\n"))
        XCTAssertEqual(
            try T7EjectResult.decoder().decode(T7EjectResult.self, from: Data(stdout.utf8)),
            result
        )
    }

    @discardableResult
    private static func roundTrip(_ result: T7EjectResult) throws -> [String: Any] {
        let data = try T7EjectResult.encoder().encode(result)
        let decoded = try T7EjectResult.decoder().decode(T7EjectResult.self, from: data)
        XCTAssertEqual(decoded, result)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private static func date(_ value: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        return try XCTUnwrap(formatter.date(from: value))
    }
}
