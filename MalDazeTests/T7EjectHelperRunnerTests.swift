import XCTest
@testable import MalDaze

final class T7EjectHelperRunnerTests: XCTestCase {
    func testIdleNotConnectedReturnsIdleWithoutPreparingTimeMachineOrEjecting() async throws {
        let timeMachine = RecordingTimeMachinePreparer(RecordingTimeMachinePreparer.idle)
        let ejector = RecordingT7Ejector()
        let runner = Self.runner(
            inventory: T7HelperRunnerFixture.unrelatedExternalOnly(),
            timeMachinePreparer: timeMachine,
            ejector: ejector
        )

        let result = try await runner.run()

        XCTAssertEqual(result.status, .idle)
        XCTAssertEqual(result.reason, .idleNotConnected)
        XCTAssertNil(result.wholeDisk)
        XCTAssertEqual(result.volumes, [])
        XCTAssertEqual(timeMachine.prepareCallCount, 0)
        XCTAssertEqual(ejector.requests, [])
    }

    func testIdleAlreadyUnmountedReturnsIdleWithoutPreparingTimeMachineOrEjecting() async throws {
        let timeMachine = RecordingTimeMachinePreparer(RecordingTimeMachinePreparer.idle)
        let ejector = RecordingT7Ejector()
        let runner = Self.runner(
            inventory: T7HelperRunnerFixture.observedT7(storageMount: nil, shieldMount: nil),
            timeMachinePreparer: timeMachine,
            ejector: ejector
        )

        let result = try await runner.run()

        XCTAssertEqual(result.status, .idle)
        XCTAssertEqual(result.reason, .idleAlreadyUnmounted)
        XCTAssertEqual(result.wholeDisk, "disk4")
        XCTAssertEqual(result.apfsContainer, "disk5")
        XCTAssertEqual(result.volumes, ["Storage", "T7 Shield"])
        XCTAssertEqual(timeMachine.prepareCallCount, 0)
        XCTAssertEqual(ejector.requests, [])
    }

    func testUnsafeAndUnexpectedResolverOutcomesReturnFailedWithoutPreparingTimeMachineOrEjecting() async throws {
        let cases: [(String, T7StaticDiskInventory, T7EjectReason)] = [
            ("internal", T7HelperRunnerFixture.observedT7(isPhysicalDiskInternal: true), .unsafeTargetInternalDisk),
            ("multiple", T7HelperRunnerFixture.targetVolumesSplitAcrossTwoExternalDisks(), .unsafeTargetMultipleDisks),
            ("unexpected", T7HelperRunnerFixture.targetNameOnlyExternalDisk(), .unexpectedError),
        ]

        for (name, inventory, reason) in cases {
            let timeMachine = RecordingTimeMachinePreparer(RecordingTimeMachinePreparer.idle)
            let ejector = RecordingT7Ejector()
            let runner = Self.runner(
                inventory: inventory,
                timeMachinePreparer: timeMachine,
                ejector: ejector
            )

            let result = try await runner.run()

            XCTAssertEqual(result.status, .failed, name)
            XCTAssertEqual(result.reason, reason, name)
            XCTAssertEqual(timeMachine.prepareCallCount, 0, name)
            XCTAssertEqual(ejector.requests, [], name)
        }
    }

    func testReadyToEjectWhenTimeMachineStillRunsReturnsFailedWithoutDiskArbitration() async throws {
        let timeMachine = RecordingTimeMachinePreparer(
            T7TimeMachinePreparationResult(
                canProceed: false,
                reason: .timeMachineStillRunning,
                timeMachineWasRunning: true,
                timeMachineStopped: false
            )
        )
        let ejector = RecordingT7Ejector()
        let runner = Self.runner(
            inventory: T7HelperRunnerFixture.observedT7(),
            timeMachinePreparer: timeMachine,
            ejector: ejector
        )

        let result = try await runner.run()

        XCTAssertEqual(timeMachine.prepareCallCount, 1)
        XCTAssertEqual(ejector.requests, [])
        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.reason, .timeMachineStillRunning)
        XCTAssertEqual(result.wholeDisk, "disk4")
        XCTAssertEqual(result.apfsContainer, "disk5")
        XCTAssertEqual(result.volumes, ["Storage", "T7 Shield"])
        XCTAssertEqual(result.remainingMountedVolumes, ["Storage", "T7 Shield"])
        XCTAssertTrue(result.timeMachineWasRunning)
        XCTAssertFalse(result.timeMachineStopped)
    }

    func testReadyToEjectWithTimeMachinePreparedCallsDiskArbitrationAndReturnsItsResult() async throws {
        let timeMachine = RecordingTimeMachinePreparer(
            T7TimeMachinePreparationResult(
                canProceed: true,
                reason: nil,
                timeMachineWasRunning: true,
                timeMachineStopped: true
            )
        )
        let expectedResult = T7EjectResult(
            status: .success,
            reason: nil,
            action: .safeEject,
            wholeDisk: "disk4",
            apfsContainer: "disk5",
            volumes: ["Storage"],
            timeMachineWasRunning: true,
            timeMachineStopped: true,
            remainingMountedVolumes: [],
            dissenterStatus: nil,
            dissenterMessage: nil,
            startedAt: Self.date(20),
            endedAt: Self.date(21),
            message: T7EjectResult.message(for: .success, reason: nil)
        )
        let ejector = RecordingT7Ejector(result: expectedResult)
        let runner = Self.runner(
            inventory: T7HelperRunnerFixture.observedT7(includeShieldVolume: false),
            timeMachinePreparer: timeMachine,
            ejector: ejector
        )

        let result = try await runner.run()

        XCTAssertEqual(timeMachine.prepareCallCount, 1)
        XCTAssertEqual(ejector.requests, [
            T7DiskArbitrationEjectRequest(
                wholeDiskIdentifier: "disk4",
                apfsContainerIdentifier: "disk5",
                mountedVolumeNames: ["Storage"],
                timeMachineWasRunning: true,
                timeMachineStopped: true
            ),
        ])
        XCTAssertEqual(result, expectedResult)
    }

    func testHelperMainPrintsOneJSONObjectAndReturnsZeroForStructuredIdleAndFailedResults() async throws {
        let cases: [T7EjectResult] = [
            T7EjectResult.idleNotConnected(startedAt: Self.date(0), endedAt: Self.date(1)),
            T7EjectResult(
                status: .failed,
                reason: .timeMachineStillRunning,
                action: .safeEject,
                wholeDisk: "disk4",
                apfsContainer: "disk5",
                volumes: ["Storage"],
                timeMachineWasRunning: true,
                timeMachineStopped: false,
                remainingMountedVolumes: [],
                dissenterStatus: nil,
                dissenterMessage: nil,
                startedAt: Self.date(2),
                endedAt: Self.date(3),
                message: T7EjectResult.message(for: .failed, reason: .timeMachineStillRunning)
            ),
        ]

        for result in cases {
            var stdout: [String] = []
            var stderr: [String] = []

            let exitCode = await T7EjectHelperMain.run(
                runner: StubT7HelperRunner(result: result),
                stdout: { stdout.append($0) },
                stderr: { stderr.append($0) }
            )

            XCTAssertEqual(exitCode, 0)
            XCTAssertEqual(stderr, [])
            XCTAssertEqual(stdout.count, 1)

            let output = stdout.joined()
            let jsonLines = output.split(separator: "\n", omittingEmptySubsequences: true)
            XCTAssertEqual(jsonLines.count, 1)
            XCTAssertEqual(
                try T7EjectResult.decoder().decode(T7EjectResult.self, from: Data(jsonLines[0].utf8)),
                result
            )
        }
    }

    func testHelperMainPrintsUnexpectedErrorJSONObjectWhenRunnerThrows() async throws {
        var stdout: [String] = []
        var stderr: [String] = []

        let exitCode = await T7EjectHelperMain.run(
            runner: ThrowingT7HelperRunner(),
            stdout: { stdout.append($0) },
            stderr: { stderr.append($0) }
        )

        XCTAssertEqual(exitCode, 1)
        XCTAssertEqual(stdout.count, 1)
        let jsonLines = stdout.joined().split(separator: "\n", omittingEmptySubsequences: true)
        XCTAssertEqual(jsonLines.count, 1)

        let result = try T7EjectResult.decoder().decode(
            T7EjectResult.self,
            from: Data(jsonLines[0].utf8)
        )
        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.reason, .unexpectedError)
        XCTAssertEqual(result.volumes, [])
        XCTAssertEqual(result.remainingMountedVolumes, [])
        XCTAssertEqual(result.message, T7EjectResult.message(for: .failed, reason: .unexpectedError))
        XCTAssertEqual(stderr.count, 1)
    }

    func testDiskUtilInventoryProviderParsesStructuredAPFSEvidenceWithoutRunningEjectCommands() throws {
        let inventory = try T7DiskUtilInventoryProvider.makeInventory(
            diskListPlist: T7DiskUtilFixture.diskList,
            apfsListPlist: T7DiskUtilFixture.apfsList,
            infoPlistsByIdentifier: T7DiskUtilFixture.infoByIdentifier
        )

        let resolution = T7TargetResolver(configuration: .samsungT7ShieldSeed)
            .resolve(in: inventory)

        XCTAssertEqual(resolution.outcome, .readyToEject)
        XCTAssertEqual(resolution.wholeDiskIdentifier, "disk4")
        XCTAssertEqual(resolution.apfsContainerIdentifier, "disk5")
        XCTAssertEqual(resolution.mountedVolumeNames, ["Storage", "T7 Shield"])
    }

    func testDiskUtilInventoryProviderFailsClosedWhenExternalEvidenceIsUnknown() throws {
        var infoByIdentifier = T7DiskUtilFixture.infoByIdentifier
        infoByIdentifier["disk4"] = [
            "DeviceIdentifier": "disk4",
            "MediaName": "PSSD T7 Shield",
            "DeviceModel": "Samsung Portable SSD T7 Shield",
            "DiskUUID": "USB-PSSD-T7-SHIELD",
        ]

        let inventory = try T7DiskUtilInventoryProvider.makeInventory(
            diskListPlist: T7DiskUtilFixture.diskList,
            apfsListPlist: T7DiskUtilFixture.apfsList,
            infoPlistsByIdentifier: infoByIdentifier
        )

        let physicalDisk = try XCTUnwrap(inventory.physicalDisks.first { $0.wholeDiskIdentifier == "disk4" })
        XCTAssertFalse(physicalDisk.isExternal)

        let resolution = T7TargetResolver(configuration: .samsungT7ShieldSeed)
            .resolve(in: inventory)
        XCTAssertEqual(resolution.outcome, .unsafeTargetInternalDisk)
        XCTAssertEqual(resolution.reason, .unsafeTargetInternalDisk)
    }

    func testLiveInventoryProviderSourceUsesDiskutilPlistOnlyForInventory() throws {
        let source = try Self.productionSource(at: "MalDaze/T7Eject/T7DiskUtilInventoryProvider.swift")

        XCTAssertTrue(source.contains("Process()"))
        XCTAssertTrue(source.contains("PropertyListSerialization"))
        XCTAssertTrue(source.contains(#""/usr/sbin/diskutil""#))
        XCTAssertNil(source.range(of: #"(?i)osascript|NSAppleScript|System Events|tell application\s+\"Finder\""#, options: .regularExpression))
        XCTAssertNil(source.range(of: #"(?i)\b(force|DADiskEject|DADiskUnmount|unmountDisk)\b"#, options: .regularExpression))
    }

    func testLiveInventoryProviderProductionRunnerUsesTimeoutInsteadOfUnboundedWait() throws {
        let source = try Self.productionSource(at: "MalDaze/T7Eject/T7DiskUtilInventoryProvider.swift")

        XCTAssertFalse(source.contains("waitUntilExit"))
        XCTAssertTrue(source.contains("terminationHandler"))
        XCTAssertTrue(source.contains("DispatchSemaphore"))
        XCTAssertTrue(source.contains("terminate()"))
        XCTAssertTrue(source.contains("commandTimedOut"))
    }

    func testHelperMainSourceCallsRealRunnerInsteadOfPlaceholderIdle() throws {
        let source = try Self.productionSource(at: "T7EjectHelper/main.swift")

        XCTAssertTrue(source.contains("T7EjectHelperRunner.live()"))
        XCTAssertFalse(source.contains("idleNotConnected"))
    }

    private static func runner(
        inventory: T7StaticDiskInventory,
        timeMachinePreparer: RecordingTimeMachinePreparer,
        ejector: RecordingT7Ejector
    ) -> T7EjectHelperRunner {
        T7EjectHelperRunner(
            inventoryProvider: StaticT7DiskInventoryProvider(inventory: inventory),
            resolver: T7TargetResolver(configuration: .samsungT7ShieldSeed),
            timeMachinePreparer: timeMachinePreparer,
            ejector: ejector,
            clock: SequenceT7HelperClock([date(10), date(11)])
        )
    }

    private static func date(_ offset: TimeInterval) -> Date {
        Date(timeIntervalSince1970: 1_780_000_000 + offset)
    }

    private static func productionSource(at relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

private final class StaticT7DiskInventoryProvider: T7DiskInventoryProviding {
    let inventoryValue: T7StaticDiskInventory

    init(inventory: T7StaticDiskInventory) {
        inventoryValue = inventory
    }

    func inventory() throws -> any T7DiskInventory {
        inventoryValue
    }
}

private final class RecordingTimeMachinePreparer: T7TimeMachinePreparing {
    static let idle = T7TimeMachinePreparationResult(
        canProceed: true,
        reason: nil,
        timeMachineWasRunning: false,
        timeMachineStopped: false
    )

    private let result: T7TimeMachinePreparationResult
    private(set) var prepareCallCount = 0

    init(_ result: T7TimeMachinePreparationResult) {
        self.result = result
    }

    func prepareForEject() async -> T7TimeMachinePreparationResult {
        prepareCallCount += 1
        return result
    }
}

private final class RecordingT7Ejector: T7DiskArbitrationEjecting {
    private let result: T7EjectResult
    private(set) var requests: [T7DiskArbitrationEjectRequest] = []

    init(result: T7EjectResult? = nil) {
        self.result = result ?? T7EjectResult(
            status: .success,
            reason: nil,
            action: .safeEject,
            wholeDisk: "disk4",
            apfsContainer: "disk5",
            volumes: ["Storage", "T7 Shield"],
            timeMachineWasRunning: false,
            timeMachineStopped: false,
            remainingMountedVolumes: [],
            dissenterStatus: nil,
            dissenterMessage: nil,
            startedAt: Date(timeIntervalSince1970: 1_780_000_020),
            endedAt: Date(timeIntervalSince1970: 1_780_000_021),
            message: T7EjectResult.message(for: .success, reason: nil)
        )
    }

    func eject(_ request: T7DiskArbitrationEjectRequest) async -> T7EjectResult {
        requests.append(request)
        return result
    }
}

private final class SequenceT7HelperClock: T7EjectHelperClock {
    private let dates: [Date]
    private let lock = NSLock()
    private var index = 0

    init(_ dates: [Date]) {
        self.dates = dates
    }

    func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        let date = dates[min(index, dates.count - 1)]
        index += 1
        return date
    }
}

private struct StubT7HelperRunner: T7EjectHelperRunning {
    let result: T7EjectResult

    func run() async throws -> T7EjectResult {
        result
    }
}

private struct ThrowingT7HelperRunner: T7EjectHelperRunning {
    func run() async throws -> T7EjectResult {
        throw RuntimeFailure()
    }

    private struct RuntimeFailure: Error {}
}

private enum T7HelperRunnerFixture {
    static let storageVolumeUUID = "16200DE4-3800-4E29-830B-6CD1211E02C5"
    static let shieldVolumeUUID = "C34DAAF1-3BDB-4B62-80F9-4621158F1A8E"
    static let apfsContainerUUID = "9E5E6C79-4DFB-481A-BC3C-A503BA356A50"
    static let physicalStoreUUID = "AB8EBBC8-85E3-412B-8EE4-F5AD94248842"

    static func observedT7(
        storageMount: String? = "/Volumes/Storage",
        shieldMount: String? = "/Volumes/T7 Shield",
        includeShieldVolume: Bool = true,
        isPhysicalDiskInternal: Bool = false
    ) -> T7StaticDiskInventory {
        var inventory = T7StaticDiskInventory(
            volumes: [
                T7VolumeEvidence(
                    name: "Storage",
                    stableIdentifier: storageVolumeUUID,
                    diskIdentifier: "disk5s1",
                    mountPoint: storageMount,
                    apfsRole: nil,
                    parentWholeDiskIdentifier: "disk5",
                    apfsContainerStableIdentifier: apfsContainerUUID,
                    physicalStoreStableIdentifier: physicalStoreUUID
                ),
            ],
            apfsContainers: [
                T7APFSContainerEvidence(
                    stableIdentifier: apfsContainerUUID,
                    diskIdentifier: "disk5",
                    physicalStoreStableIdentifier: physicalStoreUUID
                ),
            ],
            physicalStores: [
                T7PhysicalStoreEvidence(
                    stableIdentifier: physicalStoreUUID,
                    diskIdentifier: "disk4s2",
                    wholeDiskIdentifier: "disk4"
                ),
            ],
            physicalDisks: [
                T7PhysicalDiskEvidence(
                    stableIdentifier: "USB-PSSD-T7-SHIELD",
                    wholeDiskIdentifier: "disk4",
                    isExternal: !isPhysicalDiskInternal,
                    isInternal: isPhysicalDiskInternal,
                    protocolName: "USB",
                    mediaName: "PSSD T7 Shield",
                    model: "Samsung Portable SSD T7 Shield"
                ),
            ]
        )

        if includeShieldVolume {
            inventory.volumes.append(
                T7VolumeEvidence(
                    name: "T7 Shield",
                    stableIdentifier: shieldVolumeUUID,
                    diskIdentifier: "disk5s2",
                    mountPoint: shieldMount,
                    apfsRole: "Backup",
                    parentWholeDiskIdentifier: "disk5",
                    apfsContainerStableIdentifier: apfsContainerUUID,
                    physicalStoreStableIdentifier: physicalStoreUUID
                )
            )
        }

        return inventory
    }

    static func unrelatedExternalOnly() -> T7StaticDiskInventory {
        T7StaticDiskInventory(
            volumes: [
                T7VolumeEvidence(
                    name: "Archive",
                    stableIdentifier: "ARCHIVE-VOLUME",
                    diskIdentifier: "disk9s1",
                    mountPoint: "/Volumes/Archive",
                    apfsRole: nil,
                    parentWholeDiskIdentifier: "disk9",
                    apfsContainerStableIdentifier: "ARCHIVE-CONTAINER",
                    physicalStoreStableIdentifier: "ARCHIVE-STORE"
                ),
            ],
            apfsContainers: [],
            physicalStores: [],
            physicalDisks: [
                T7PhysicalDiskEvidence(
                    stableIdentifier: "ARCHIVE-DISK",
                    wholeDiskIdentifier: "disk9",
                    isExternal: true,
                    isInternal: false,
                    protocolName: "USB",
                    mediaName: "Archive SSD",
                    model: nil
                ),
            ]
        )
    }

    static func targetNameOnlyExternalDisk() -> T7StaticDiskInventory {
        T7StaticDiskInventory(
            volumes: [
                T7VolumeEvidence(
                    name: "Storage",
                    stableIdentifier: nil,
                    diskIdentifier: "disk21s1",
                    mountPoint: "/Volumes/Storage",
                    apfsRole: nil,
                    parentWholeDiskIdentifier: "disk21",
                    apfsContainerStableIdentifier: nil,
                    physicalStoreStableIdentifier: nil
                ),
            ],
            apfsContainers: [],
            physicalStores: [],
            physicalDisks: [
                T7PhysicalDiskEvidence(
                    stableIdentifier: nil,
                    wholeDiskIdentifier: "disk21",
                    isExternal: true,
                    isInternal: false,
                    protocolName: "USB",
                    mediaName: nil,
                    model: nil
                ),
            ]
        )
    }

    static func targetVolumesSplitAcrossTwoExternalDisks() -> T7StaticDiskInventory {
        var inventory = observedT7(includeShieldVolume: false)
        inventory.volumes.append(
            T7VolumeEvidence(
                name: "T7 Shield",
                stableIdentifier: shieldVolumeUUID,
                diskIdentifier: "disk7s1",
                mountPoint: "/Volumes/T7 Shield",
                apfsRole: "Backup",
                parentWholeDiskIdentifier: "disk8",
                apfsContainerStableIdentifier: "11111111-1111-1111-1111-111111111111",
                physicalStoreStableIdentifier: "22222222-2222-2222-2222-222222222222"
            )
        )
        inventory.apfsContainers.append(
            T7APFSContainerEvidence(
                stableIdentifier: "11111111-1111-1111-1111-111111111111",
                diskIdentifier: "disk8",
                physicalStoreStableIdentifier: "22222222-2222-2222-2222-222222222222"
            )
        )
        inventory.physicalStores.append(
            T7PhysicalStoreEvidence(
                stableIdentifier: "22222222-2222-2222-2222-222222222222",
                diskIdentifier: "disk7s2",
                wholeDiskIdentifier: "disk7"
            )
        )
        inventory.physicalDisks.append(
            T7PhysicalDiskEvidence(
                stableIdentifier: "USB-PSSD-T7-SHIELD-2",
                wholeDiskIdentifier: "disk7",
                isExternal: true,
                isInternal: false,
                protocolName: "USB",
                mediaName: "PSSD T7 Shield",
                model: "Samsung Portable SSD T7 Shield"
            )
        )
        return inventory
    }
}

private enum T7DiskUtilFixture {
    static let diskList: [String: Any] = [
        "AllDisks": ["disk4", "disk4s2", "disk5", "disk5s1", "disk5s2"],
    ]

    static let apfsList: [String: Any] = [
        "Containers": [
            [
                "ContainerReference": "disk5",
                "APFSContainerUUID": T7HelperRunnerFixture.apfsContainerUUID,
                "PhysicalStores": [
                    [
                        "DeviceIdentifier": "disk4s2",
                        "DiskUUID": T7HelperRunnerFixture.physicalStoreUUID,
                    ],
                ],
                "Volumes": [
                    [
                        "DeviceIdentifier": "disk5s1",
                        "Name": "Storage",
                        "APFSVolumeUUID": T7HelperRunnerFixture.storageVolumeUUID,
                        "MountPoint": "/Volumes/Storage",
                        "Roles": [],
                    ],
                    [
                        "DeviceIdentifier": "disk5s2",
                        "Name": "T7 Shield",
                        "APFSVolumeUUID": T7HelperRunnerFixture.shieldVolumeUUID,
                        "MountPoint": "/Volumes/T7 Shield",
                        "Roles": ["Backup"],
                    ],
                ],
            ],
        ],
    ]

    static let infoByIdentifier: [String: [String: Any]] = [
        "disk4": [
            "DeviceIdentifier": "disk4",
            "Internal": false,
            "Ejectable": true,
            "BusProtocol": "USB",
            "MediaName": "PSSD T7 Shield",
            "DeviceModel": "Samsung Portable SSD T7 Shield",
            "DiskUUID": "USB-PSSD-T7-SHIELD",
        ],
        "disk4s2": [
            "DeviceIdentifier": "disk4s2",
            "ParentWholeDisk": "disk4",
            "DiskUUID": T7HelperRunnerFixture.physicalStoreUUID,
        ],
    ]
}
