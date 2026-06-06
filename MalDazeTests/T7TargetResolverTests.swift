import XCTest
@testable import MalDaze

final class T7TargetResolverTests: XCTestCase {
    func testResolvesBothTargetVolumesMountedToExternalPhysicalWholeDisk() {
        let resolution = T7TargetResolver(configuration: .samsungT7ShieldSeed)
            .resolve(in: T7ResolverFixture.observedT7())

        XCTAssertEqual(resolution.outcome, .readyToEject)
        XCTAssertTrue(resolution.shouldAttemptEject)
        XCTAssertNil(resolution.reason)
        XCTAssertEqual(resolution.wholeDiskIdentifier, "disk4")
        XCTAssertEqual(resolution.apfsContainerIdentifier, "disk5")
        XCTAssertEqual(resolution.physicalStoreIdentifier, "disk4s2")
        XCTAssertEqual(resolution.mountedVolumeNames, ["Storage", "T7 Shield"])
    }

    func testResolvesOnlyStorageMountedToSameTargetDisk() {
        let resolution = T7TargetResolver(configuration: .samsungT7ShieldSeed)
            .resolve(in: T7ResolverFixture.observedT7(includeShieldVolume: false))

        XCTAssertEqual(resolution.outcome, .readyToEject)
        XCTAssertTrue(resolution.shouldAttemptEject)
        XCTAssertEqual(resolution.wholeDiskIdentifier, "disk4")
        XCTAssertEqual(resolution.apfsContainerIdentifier, "disk5")
        XCTAssertEqual(resolution.physicalStoreIdentifier, "disk4s2")
        XCTAssertEqual(resolution.mountedVolumeNames, ["Storage"])
    }

    func testTargetAbsentReturnsIdleNotConnected() {
        let resolution = T7TargetResolver(configuration: .samsungT7ShieldSeed)
            .resolve(in: T7ResolverFixture.unrelatedExternalOnly())

        XCTAssertEqual(resolution.outcome, .idleNotConnected)
        XCTAssertFalse(resolution.shouldAttemptEject)
        XCTAssertEqual(resolution.reason, .idleNotConnected)
        XCTAssertNil(resolution.wholeDiskIdentifier)
        XCTAssertEqual(resolution.mountedVolumeNames, [])
    }

    func testTargetAlreadyUnmountedIsDistinguishableFromAbsent() {
        let resolution = T7TargetResolver(configuration: .samsungT7ShieldSeed)
            .resolve(in: T7ResolverFixture.observedT7(storageMount: nil, shieldMount: nil))

        XCTAssertEqual(resolution.outcome, .idleAlreadyUnmounted)
        XCTAssertFalse(resolution.shouldAttemptEject)
        XCTAssertEqual(resolution.reason, .idleAlreadyUnmounted)
        XCTAssertEqual(resolution.wholeDiskIdentifier, "disk4")
        XCTAssertEqual(resolution.apfsContainerIdentifier, "disk5")
        XCTAssertEqual(resolution.knownVolumeNames, ["Storage", "T7 Shield"])
        XCTAssertEqual(resolution.mountedVolumeNames, [])
    }

    func testTargetVolumesOnMultiplePhysicalDisksAreRejected() {
        let resolution = T7TargetResolver(configuration: .samsungT7ShieldSeed)
            .resolve(in: T7ResolverFixture.targetVolumesSplitAcrossTwoExternalDisks())

        XCTAssertEqual(resolution.outcome, .unsafeTargetMultipleDisks)
        XCTAssertFalse(resolution.shouldAttemptEject)
        XCTAssertEqual(resolution.reason, .unsafeTargetMultipleDisks)
        XCTAssertNil(resolution.wholeDiskIdentifier)
    }

    func testInternalDiskResolvedFromTargetEvidenceIsRejected() {
        let resolution = T7TargetResolver(configuration: .samsungT7ShieldSeed)
            .resolve(in: T7ResolverFixture.observedT7(isPhysicalDiskInternal: true))

        XCTAssertEqual(resolution.outcome, .unsafeTargetInternalDisk)
        XCTAssertFalse(resolution.shouldAttemptEject)
        XCTAssertEqual(resolution.reason, .unsafeTargetInternalDisk)
        XCTAssertEqual(resolution.wholeDiskIdentifier, "disk4")
    }

    func testSeededUnmountedInternalPhysicalStoreIsRejectedWithoutTargetVolumes() {
        let resolution = T7TargetResolver(configuration: .samsungT7ShieldSeed)
            .resolve(in: T7ResolverFixture.knownUnmountedT7PhysicalStore(isInternal: true, isExternal: false))

        XCTAssertEqual(resolution.outcome, .unsafeTargetInternalDisk)
        XCTAssertFalse(resolution.shouldAttemptEject)
        XCTAssertEqual(resolution.reason, .unsafeTargetInternalDisk)
        XCTAssertEqual(resolution.wholeDiskIdentifier, "disk4")
        XCTAssertEqual(resolution.mountedVolumeNames, [])
    }

    func testTargetVolumeNameWithoutStrongStableEvidenceDoesNotEject() {
        let resolution = T7TargetResolver(configuration: .samsungT7ShieldSeed)
            .resolve(in: T7ResolverFixture.targetNameOnlyExternalDisk())

        XCTAssertEqual(resolution.outcome, .unexpectedError)
        XCTAssertFalse(resolution.shouldAttemptEject)
        XCTAssertEqual(resolution.reason, .unexpectedError)
    }

    func testMismatchedAPFSContainerPhysicalStoreDoesNotEject() {
        let resolution = T7TargetResolver(configuration: .samsungT7ShieldSeed)
            .resolve(in: T7ResolverFixture.containerStoreMismatch())

        XCTAssertEqual(resolution.outcome, .unexpectedError)
        XCTAssertFalse(resolution.shouldAttemptEject)
        XCTAssertEqual(resolution.reason, .unexpectedError)
    }

    func testMountedNonExternalPhysicalDiskIsRejected() {
        let resolution = T7TargetResolver(configuration: .samsungT7ShieldSeed)
            .resolve(in: T7ResolverFixture.observedT7(isPhysicalDiskExternal: false))

        XCTAssertEqual(resolution.outcome, .unsafeTargetInternalDisk)
        XCTAssertFalse(resolution.shouldAttemptEject)
        XCTAssertEqual(resolution.reason, .unsafeTargetInternalDisk)
        XCTAssertEqual(resolution.wholeDiskIdentifier, "disk4")
    }

    func testUnrelatedExternalDisksAreIgnoredWhenTargetIsPresent() {
        let resolution = T7TargetResolver(configuration: .samsungT7ShieldSeed)
            .resolve(in: T7ResolverFixture.observedT7(includeUnrelatedExternalDisk: true))

        XCTAssertEqual(resolution.outcome, .readyToEject)
        XCTAssertTrue(resolution.shouldAttemptEject)
        XCTAssertEqual(resolution.wholeDiskIdentifier, "disk4")
        XCTAssertEqual(resolution.mountedVolumeNames, ["Storage", "T7 Shield"])
        XCTAssertFalse(resolution.physicalDiskIdentifiersConsidered.contains("disk9"))
    }
}

final class T7TargetResolverSourceSafetyTests: XCTestCase {
    func testResolverConfigurationDoesNotHardCodeDynamicDiskIdentifiers() throws {
        let source = try Self.productionSource(at: "MalDaze/T7Eject/T7TargetResolver.swift")
        let config = T7TargetResolverConfiguration.samsungT7ShieldSeed

        XCTAssertTrue(config.stableConfigurationIdentifiers.contains(T7ResolverFixture.storageVolumeUUID))
        XCTAssertTrue(config.stableConfigurationIdentifiers.contains(T7ResolverFixture.shieldVolumeUUID))
        XCTAssertTrue(config.stableConfigurationIdentifiers.contains(T7ResolverFixture.apfsContainerUUID))
        XCTAssertTrue(config.stableConfigurationIdentifiers.contains(T7ResolverFixture.physicalStoreUUID))
        XCTAssertFalse(
            config.stableConfigurationIdentifiers.contains { Self.containsDynamicDiskIdentifier($0) },
            "Resolver configuration must persist stable UUID/media identifiers, not dynamic disk identifiers."
        )

        XCTAssertNil(
            source.range(of: #""(?:/dev/)?disk[0-9][^"]*""#, options: .regularExpression),
            "Production resolver source must not hard-code dynamic disk identifiers in string configuration."
        )
        XCTAssertFalse(source.contains("\"disk4\""))
        XCTAssertFalse(source.contains("\"disk5\""))
        XCTAssertFalse(source.contains("\"/dev/disk4\""))
    }

    private static func productionSource(at relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }

    private static func containsDynamicDiskIdentifier(_ value: String) -> Bool {
        value.range(of: #"^(?:/dev/)?disk[0-9]"#, options: .regularExpression) != nil
    }
}

private enum T7ResolverFixture {
    static let storageVolumeUUID = "16200DE4-3800-4E29-830B-6CD1211E02C5"
    static let shieldVolumeUUID = "C34DAAF1-3BDB-4B62-80F9-4621158F1A8E"
    static let apfsContainerUUID = "9E5E6C79-4DFB-481A-BC3C-A503BA356A50"
    static let physicalStoreUUID = "AB8EBBC8-85E3-412B-8EE4-F5AD94248842"

    static func observedT7(
        storageMount: String? = "/Volumes/Storage",
        shieldMount: String? = "/Volumes/T7 Shield",
        includeShieldVolume: Bool = true,
        isPhysicalDiskInternal: Bool = false,
        isPhysicalDiskExternal: Bool? = nil,
        includeUnrelatedExternalDisk: Bool = false
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
                    isExternal: isPhysicalDiskExternal ?? !isPhysicalDiskInternal,
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

        if includeUnrelatedExternalDisk {
            inventory.append(contentsOf: unrelatedExternalDisk())
        }

        return inventory
    }

    static func unrelatedExternalOnly() -> T7StaticDiskInventory {
        unrelatedExternalDisk()
    }

    static func knownUnmountedT7PhysicalStore(isInternal: Bool, isExternal: Bool) -> T7StaticDiskInventory {
        T7StaticDiskInventory(
            volumes: [],
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
                    isExternal: isExternal,
                    isInternal: isInternal,
                    protocolName: "USB",
                    mediaName: "PSSD T7 Shield",
                    model: "Samsung Portable SSD T7 Shield"
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

    static func containerStoreMismatch() -> T7StaticDiskInventory {
        var inventory = observedT7(includeShieldVolume: false)
        inventory.apfsContainers = [
            T7APFSContainerEvidence(
                stableIdentifier: apfsContainerUUID,
                diskIdentifier: "disk5",
                physicalStoreStableIdentifier: "D6AC5566-9DE5-40FA-98E2-B77592B5A6F8"
            ),
        ]
        return inventory
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
                parentWholeDiskIdentifier: "disk7",
                apfsContainerStableIdentifier: "82B01247-F06B-443A-A0F4-7D45B4B9FA2D",
                physicalStoreStableIdentifier: "20A19D11-915E-42EF-A855-F0127DB5A3EA"
            )
        )
        inventory.apfsContainers.append(
            T7APFSContainerEvidence(
                stableIdentifier: "82B01247-F06B-443A-A0F4-7D45B4B9FA2D",
                diskIdentifier: "disk7",
                physicalStoreStableIdentifier: "20A19D11-915E-42EF-A855-F0127DB5A3EA"
            )
        )
        inventory.physicalStores.append(
            T7PhysicalStoreEvidence(
                stableIdentifier: "20A19D11-915E-42EF-A855-F0127DB5A3EA",
                diskIdentifier: "disk6s2",
                wholeDiskIdentifier: "disk6"
            )
        )
        inventory.physicalDisks.append(
            T7PhysicalDiskEvidence(
                stableIdentifier: "USB-PSSD-T7-SHIELD-SECOND",
                wholeDiskIdentifier: "disk6",
                isExternal: true,
                isInternal: false,
                protocolName: "USB",
                mediaName: "PSSD T7 Shield",
                model: "Samsung Portable SSD T7 Shield"
            )
        )
        return inventory
    }

    private static func unrelatedExternalDisk() -> T7StaticDiskInventory {
        T7StaticDiskInventory(
            volumes: [
                T7VolumeEvidence(
                    name: "Archive",
                    stableIdentifier: "59B68BC9-A527-430E-B5CC-7FB5BE2C4FE2",
                    diskIdentifier: "disk10s1",
                    mountPoint: "/Volumes/Archive",
                    apfsRole: nil,
                    parentWholeDiskIdentifier: "disk10",
                    apfsContainerStableIdentifier: "DDE2AD2C-D863-4C62-BE90-656E0337A4EC",
                    physicalStoreStableIdentifier: "FE7F8C48-C84B-480D-9359-B605E45DB0A2"
                ),
            ],
            apfsContainers: [
                T7APFSContainerEvidence(
                    stableIdentifier: "DDE2AD2C-D863-4C62-BE90-656E0337A4EC",
                    diskIdentifier: "disk10",
                    physicalStoreStableIdentifier: "FE7F8C48-C84B-480D-9359-B605E45DB0A2"
                ),
            ],
            physicalStores: [
                T7PhysicalStoreEvidence(
                    stableIdentifier: "FE7F8C48-C84B-480D-9359-B605E45DB0A2",
                    diskIdentifier: "disk9s2",
                    wholeDiskIdentifier: "disk9"
                ),
            ],
            physicalDisks: [
                T7PhysicalDiskEvidence(
                    stableIdentifier: "USB-SANDISK-EXTREME",
                    wholeDiskIdentifier: "disk9",
                    isExternal: true,
                    isInternal: false,
                    protocolName: "USB",
                    mediaName: "SanDisk Extreme",
                    model: "SanDisk Extreme"
                ),
            ]
        )
    }
}
