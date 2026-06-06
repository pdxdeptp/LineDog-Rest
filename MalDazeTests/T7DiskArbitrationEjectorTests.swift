import XCTest
@testable import MalDaze

final class T7DiskArbitrationEjectorTests: XCTestCase {
    func testUnmountSuccessThenEjectSuccessReturnsSuccess() async {
        let operation = FakeDiskArbitrationOperation(
            unmountResult: .success,
            ejectResult: .success,
            remainingMountedVolumes: []
        )
        let ejector = T7DiskArbitrationEjector(operation: operation, clock: TestClock())

        let result = await ejector.eject(Self.request())

        XCTAssertEqual(operation.events, [.unmountWholeDisk("disk4"), .ejectWholeDisk("disk4")])
        XCTAssertEqual(result.status, .success)
        XCTAssertNil(result.reason)
        XCTAssertEqual(result.wholeDisk, "disk4")
        XCTAssertEqual(result.apfsContainer, "disk5")
        XCTAssertEqual(result.volumes, ["Storage", "T7 Shield"])
        XCTAssertEqual(result.remainingMountedVolumes, [])
        XCTAssertNil(result.dissenterStatus)
        XCTAssertNil(result.dissenterMessage)
        XCTAssertEqual(result.message, "T7 已安全推出。")
    }

    func testUnmountDissenterStopsBeforeEjectAndReturnsDiagnostics() async {
        let operation = FakeDiskArbitrationOperation(
            unmountResult: .dissented(T7DiskArbitrationDissenter(status: 49153, message: "Resource busy")),
            ejectResult: .success,
            remainingMountedVolumes: ["Storage"]
        )
        let ejector = T7DiskArbitrationEjector(operation: operation, clock: TestClock())

        let result = await ejector.eject(Self.request())

        XCTAssertEqual(operation.events, [.unmountWholeDisk("disk4")])
        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.reason, .diskBusy)
        XCTAssertEqual(result.remainingMountedVolumes, ["Storage"])
        XCTAssertEqual(result.dissenterStatus, 49153)
        XCTAssertEqual(result.dissenterMessage, "Resource busy")
        XCTAssertEqual(result.message, "T7 正在被占用，未强制推出。")
    }

    func testEjectDissenterAfterUnmountReturnsUnmountSucceededEjectFailed() async {
        let operation = FakeDiskArbitrationOperation(
            unmountResult: .success,
            ejectResult: .dissented(T7DiskArbitrationDissenter(status: 49154, message: "Eject refused")),
            remainingMountedVolumes: []
        )
        let ejector = T7DiskArbitrationEjector(operation: operation, clock: TestClock())

        let result = await ejector.eject(Self.request())

        XCTAssertEqual(operation.events, [.unmountWholeDisk("disk4"), .ejectWholeDisk("disk4")])
        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.reason, .unmountSucceededEjectFailed)
        XCTAssertEqual(result.remainingMountedVolumes, [])
        XCTAssertEqual(result.dissenterStatus, 49154)
        XCTAssertEqual(result.dissenterMessage, "Eject refused")
        XCTAssertEqual(result.message, "T7 已卸载但推出失败。")
    }

    func testRemainingMountedVolumeEvidenceIsReportedAfterFailure() async {
        let operation = FakeDiskArbitrationOperation(
            unmountResult: .dissented(T7DiskArbitrationDissenter(status: 49155, message: "Volume still in use")),
            ejectResult: .success,
            remainingMountedVolumes: ["T7 Shield"]
        )
        let ejector = T7DiskArbitrationEjector(operation: operation, clock: TestClock())

        let result = await ejector.eject(Self.request(mountedVolumeNames: ["Storage", "T7 Shield"]))

        XCTAssertEqual(result.volumes, ["Storage", "T7 Shield"])
        XCTAssertEqual(result.remainingMountedVolumes, ["T7 Shield"])
        XCTAssertEqual(result.dissenterStatus, 49155)
        XCTAssertEqual(result.dissenterMessage, "Volume still in use")
    }

    func testSessionRemainingMountedVolumesIgnoresSameNamedVolumeOnDifferentWholeDisk() async {
        let provider = StaticMountedVolumeProvider(volumes: [
            T7MountedVolumeEvidence(
                name: "Storage",
                mountPath: "/Volumes/Storage",
                wholeDiskIdentifier: "disk9",
                stableIdentifier: "UNRELATED-STORAGE"
            ),
            T7MountedVolumeEvidence(
                name: "T7 Shield",
                mountPath: "/Volumes/T7 Shield",
                wholeDiskIdentifier: "disk4",
                stableIdentifier: "TARGET-SHIELD"
            ),
            T7MountedVolumeEvidence(
                name: "Archive",
                mountPath: "/Volumes/Archive",
                wholeDiskIdentifier: "disk4",
                stableIdentifier: "TARGET-ARCHIVE"
            ),
        ])
        let operation = T7DiskArbitrationSessionOperation(mountedVolumeProvider: provider)

        let remaining = await operation.remainingMountedVolumes(
            named: ["Storage", "T7 Shield"],
            onWholeDisk: "/dev/disk4"
        )

        XCTAssertEqual(remaining, ["T7 Shield"])
    }

    func testSessionRemainingMountedVolumesUsesStableEvidenceWhenWholeDiskIsUnavailable() async {
        let provider = StaticMountedVolumeProvider(volumes: [
            T7MountedVolumeEvidence(
                name: "Storage",
                mountPath: "/Volumes/Storage",
                wholeDiskIdentifier: nil,
                stableIdentifier: "UNRELATED-STORAGE"
            ),
            T7MountedVolumeEvidence(
                name: "T7 Shield",
                mountPath: "/Volumes/T7 Shield",
                wholeDiskIdentifier: nil,
                stableIdentifier: "C34DAAF1-3BDB-4B62-80F9-4621158F1A8E"
            ),
        ])
        let operation = T7DiskArbitrationSessionOperation(mountedVolumeProvider: provider)

        let remaining = await operation.remainingMountedVolumes(
            named: ["Storage", "T7 Shield"],
            onWholeDisk: "disk4"
        )

        XCTAssertEqual(remaining, ["T7 Shield"])
    }

    func testDiskArbitrationCallbackContextIsBalancedWithoutPassRetainedTimeoutLeak() throws {
        let source = try Self.productionSource(at: "MalDaze/T7Eject/T7DiskArbitrationEjector.swift")

        XCTAssertFalse(source.contains("Unmanaged.passRetained(box)"))
        XCTAssertTrue(source.contains("retainedContext"))
        XCTAssertTrue(source.contains("unregister(context:"))
    }

    func testDiskArbitrationAdapterUsesWholeDiskUnmountThenDefaultEjectWithoutForce() throws {
        let source = try Self.productionSource(at: "MalDaze/T7Eject/T7DiskArbitrationEjector.swift")

        XCTAssertTrue(source.contains("import DiskArbitration"))
        XCTAssertTrue(source.contains("DASessionSetDispatchQueue"))
        XCTAssertTrue(source.contains("DADiskUnmount("))
        XCTAssertTrue(source.contains("kDADiskUnmountOptionWhole"))
        XCTAssertTrue(source.contains("DADiskEject("))
        XCTAssertTrue(source.contains("kDADiskEjectOptionDefault"))
        XCTAssertFalse(source.contains("kDADiskUnmountOptionForce"))
        XCTAssertFalse(source.contains("DADiskUnmountOptionForce"))
        XCTAssertNil(source.range(of: #"(?i)\bforce\s*[:=]\s*true\b"#, options: .regularExpression))
    }

    func testDiskArbitrationAdapterDoesNotUseFinderOrSystemEventsAutomation() throws {
        let source = try Self.productionSource(at: "MalDaze/T7Eject/T7DiskArbitrationEjector.swift")

        let forbiddenPatterns = [
            #"(?i)osascript"#,
            #"(?i)NSAppleScript"#,
            #"(?i)System Events"#,
            #"(?i)tell application\s+\"Finder\""#,
            #"(?i)com\.apple\.Finder"#,
            #"(?i)Finder[^\n]*(?:eject|unmount)"#,
        ]

        for pattern in forbiddenPatterns {
            XCTAssertNil(
                source.range(of: pattern, options: .regularExpression),
                "Disk Arbitration adapter must not contain forbidden automation pattern: \(pattern)"
            )
        }
    }

    private static func request(
        mountedVolumeNames: [String] = ["Storage", "T7 Shield"]
    ) -> T7DiskArbitrationEjectRequest {
        T7DiskArbitrationEjectRequest(
            wholeDiskIdentifier: "disk4",
            apfsContainerIdentifier: "disk5",
            mountedVolumeNames: mountedVolumeNames,
            timeMachineWasRunning: false,
            timeMachineStopped: false
        )
    }

    private static func productionSource(at relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

private final class FakeDiskArbitrationOperation: T7DiskArbitrationOperating {
    enum Event: Equatable {
        case unmountWholeDisk(String)
        case ejectWholeDisk(String)
    }

    private let unmountResult: T7DiskArbitrationOperationResult
    private let ejectResult: T7DiskArbitrationOperationResult
    private let remainingMountedVolumes: [String]
    private(set) var events: [Event] = []

    init(
        unmountResult: T7DiskArbitrationOperationResult,
        ejectResult: T7DiskArbitrationOperationResult,
        remainingMountedVolumes: [String]
    ) {
        self.unmountResult = unmountResult
        self.ejectResult = ejectResult
        self.remainingMountedVolumes = remainingMountedVolumes
    }

    func unmountWholeDisk(_ wholeDiskIdentifier: String) async -> T7DiskArbitrationOperationResult {
        events.append(.unmountWholeDisk(wholeDiskIdentifier))
        return unmountResult
    }

    func ejectWholeDisk(_ wholeDiskIdentifier: String) async -> T7DiskArbitrationOperationResult {
        events.append(.ejectWholeDisk(wholeDiskIdentifier))
        return ejectResult
    }

    func remainingMountedVolumes(
        named targetVolumeNames: [String],
        onWholeDisk wholeDiskIdentifier: String
    ) async -> [String] {
        remainingMountedVolumes.filter { targetVolumeNames.contains($0) }
    }
}

private struct TestClock: T7DiskArbitrationClock {
    func now() -> Date {
        Date(timeIntervalSince1970: 1_780_000_000)
    }
}

private struct StaticMountedVolumeProvider: T7MountedVolumeProviding {
    let volumes: [T7MountedVolumeEvidence]

    func mountedVolumes() -> [T7MountedVolumeEvidence] {
        volumes
    }
}
