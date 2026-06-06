import Foundation

protocol T7DiskInventory {
    var volumes: [T7VolumeEvidence] { get }
    var apfsContainers: [T7APFSContainerEvidence] { get }
    var physicalStores: [T7PhysicalStoreEvidence] { get }
    var physicalDisks: [T7PhysicalDiskEvidence] { get }
}

struct T7StaticDiskInventory: T7DiskInventory, Equatable {
    var volumes: [T7VolumeEvidence]
    var apfsContainers: [T7APFSContainerEvidence]
    var physicalStores: [T7PhysicalStoreEvidence]
    var physicalDisks: [T7PhysicalDiskEvidence]

    mutating func append(contentsOf other: T7StaticDiskInventory) {
        volumes.append(contentsOf: other.volumes)
        apfsContainers.append(contentsOf: other.apfsContainers)
        physicalStores.append(contentsOf: other.physicalStores)
        physicalDisks.append(contentsOf: other.physicalDisks)
    }
}

struct T7VolumeEvidence: Equatable {
    let name: String
    let stableIdentifier: String?
    let diskIdentifier: String?
    let mountPoint: String?
    let apfsRole: String?
    let parentWholeDiskIdentifier: String?
    let apfsContainerStableIdentifier: String?
    let physicalStoreStableIdentifier: String?

    init(
        name: String,
        stableIdentifier: String?,
        diskIdentifier: String?,
        mountPoint: String?,
        apfsRole: String?,
        parentWholeDiskIdentifier: String?,
        apfsContainerStableIdentifier: String?,
        physicalStoreStableIdentifier: String?
    ) {
        self.name = name
        self.stableIdentifier = stableIdentifier
        self.diskIdentifier = diskIdentifier
        self.mountPoint = mountPoint
        self.apfsRole = apfsRole
        self.parentWholeDiskIdentifier = parentWholeDiskIdentifier
        self.apfsContainerStableIdentifier = apfsContainerStableIdentifier
        self.physicalStoreStableIdentifier = physicalStoreStableIdentifier
    }
}

struct T7APFSContainerEvidence: Equatable {
    let stableIdentifier: String
    let diskIdentifier: String?
    let physicalStoreStableIdentifier: String?
}

struct T7PhysicalStoreEvidence: Equatable {
    let stableIdentifier: String
    let diskIdentifier: String?
    let wholeDiskIdentifier: String
}

struct T7PhysicalDiskEvidence: Equatable {
    let stableIdentifier: String?
    let wholeDiskIdentifier: String
    let isExternal: Bool
    let isInternal: Bool
    let protocolName: String?
    let mediaName: String?
    let model: String?
}

struct T7TargetResolverConfiguration: Equatable {
    let targetVolumeNames: [String]
    let volumeStableIdentifiersByName: [String: Set<String>]
    let apfsContainerStableIdentifiers: Set<String>
    let physicalStoreStableIdentifiers: Set<String>
    let acceptedMediaNames: Set<String>
    let acceptedMediaModelTerms: Set<String>

    init(
        targetVolumeNames: [String],
        volumeStableIdentifiersByName: [String: Set<String>],
        apfsContainerStableIdentifiers: Set<String>,
        physicalStoreStableIdentifiers: Set<String>,
        acceptedMediaNames: Set<String>,
        acceptedMediaModelTerms: Set<String>
    ) {
        self.targetVolumeNames = targetVolumeNames
        self.volumeStableIdentifiersByName = volumeStableIdentifiersByName.mapValues { identifiers in
            Set(identifiers.map(Self.normalizedStableIdentifier))
        }
        self.apfsContainerStableIdentifiers = Set(apfsContainerStableIdentifiers.map(Self.normalizedStableIdentifier))
        self.physicalStoreStableIdentifiers = Set(physicalStoreStableIdentifiers.map(Self.normalizedStableIdentifier))
        self.acceptedMediaNames = Set(acceptedMediaNames.map(Self.normalizedMetadataValue))
        self.acceptedMediaModelTerms = Set(acceptedMediaModelTerms.map(Self.normalizedMetadataValue))
    }

    static let samsungT7ShieldSeed = T7TargetResolverConfiguration(
        targetVolumeNames: ["Storage", "T7 Shield"],
        volumeStableIdentifiersByName: [
            "Storage": Set(["16200DE4-3800-4E29-830B-6CD1211E02C5"]),
            "T7 Shield": Set(["C34DAAF1-3BDB-4B62-80F9-4621158F1A8E"]),
        ],
        apfsContainerStableIdentifiers: Set(["9E5E6C79-4DFB-481A-BC3C-A503BA356A50"]),
        physicalStoreStableIdentifiers: Set(["AB8EBBC8-85E3-412B-8EE4-F5AD94248842"]),
        acceptedMediaNames: Set(["PSSD T7 Shield"]),
        acceptedMediaModelTerms: Set(["Samsung", "T7 Shield"])
    )

    var stableConfigurationIdentifiers: [String] {
        var identifiers = volumeStableIdentifiersByName
            .flatMap { $0.value }
        identifiers.append(contentsOf: apfsContainerStableIdentifiers)
        identifiers.append(contentsOf: physicalStoreStableIdentifiers)
        identifiers.append(contentsOf: acceptedMediaNames)
        identifiers.append(contentsOf: acceptedMediaModelTerms)
        return Array(Set(identifiers)).sorted()
    }

    func isTargetVolumeName(_ name: String) -> Bool {
        targetVolumeNames.contains(name)
    }

    func acceptsStableIdentifier(_ stableIdentifier: String?, forVolumeName name: String) -> Bool {
        guard let expected = volumeStableIdentifiersByName[name], !expected.isEmpty else {
            return true
        }
        guard let stableIdentifier else {
            return false
        }
        return expected.contains(Self.normalizedStableIdentifier(stableIdentifier))
    }

    func acceptsAPFSContainerStableIdentifier(_ stableIdentifier: String?) -> Bool {
        acceptsStableIdentifier(stableIdentifier, in: apfsContainerStableIdentifiers)
    }

    func acceptsPhysicalStoreStableIdentifier(_ stableIdentifier: String?) -> Bool {
        acceptsStableIdentifier(stableIdentifier, in: physicalStoreStableIdentifiers)
    }

    func acceptsSamsungMetadata(for disk: T7PhysicalDiskEvidence) -> Bool {
        let mediaMatches = disk.mediaName.map { mediaName in
            acceptedMediaNames.contains(Self.normalizedMetadataValue(mediaName))
        } ?? false
        let modelMatches = disk.model.map { model in
            let normalizedModel = Self.normalizedMetadataValue(model)
            return !acceptedMediaModelTerms.isEmpty
                && acceptedMediaModelTerms.allSatisfy { normalizedModel.contains($0) }
        } ?? false
        return mediaMatches || modelMatches
    }

    private func acceptsStableIdentifier(_ stableIdentifier: String?, in expected: Set<String>) -> Bool {
        guard !expected.isEmpty else {
            return true
        }
        guard let stableIdentifier else {
            return false
        }
        return expected.contains(Self.normalizedStableIdentifier(stableIdentifier))
    }

    private static func normalizedStableIdentifier(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private static func normalizedMetadataValue(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

enum T7TargetResolutionOutcome: Equatable {
    case readyToEject
    case idleNotConnected
    case idleAlreadyUnmounted
    case unsafeTargetMultipleDisks
    case unsafeTargetInternalDisk
    case unexpectedError
}

struct T7TargetResolution: Equatable {
    let outcome: T7TargetResolutionOutcome
    let reason: T7EjectReason?
    let wholeDiskIdentifier: String?
    let apfsContainerIdentifier: String?
    let physicalStoreIdentifier: String?
    let knownVolumeNames: [String]
    let mountedVolumeNames: [String]
    let physicalDiskIdentifiersConsidered: [String]

    var shouldAttemptEject: Bool {
        outcome == .readyToEject
    }
}

struct T7TargetResolver {
    let configuration: T7TargetResolverConfiguration

    init(configuration: T7TargetResolverConfiguration = .samsungT7ShieldSeed) {
        self.configuration = configuration
    }

    func resolve(in inventory: T7DiskInventory) -> T7TargetResolution {
        let targetVolumes = inventory.volumes.filter { configuration.isTargetVolumeName($0.name) }

        guard !targetVolumes.isEmpty else {
            if let knownTarget = resolveKnownUnmountedTarget(in: inventory) {
                if knownTarget.physicalDisk.isInternal || !knownTarget.physicalDisk.isExternal {
                    return resolution(
                        outcome: .unsafeTargetInternalDisk,
                        reason: .unsafeTargetInternalDisk,
                        candidates: [knownTarget],
                        volumes: []
                    )
                }
                return resolution(
                    outcome: .idleAlreadyUnmounted,
                    reason: .idleAlreadyUnmounted,
                    candidates: [knownTarget],
                    volumes: []
                )
            }
            return T7TargetResolution(
                outcome: .idleNotConnected,
                reason: .idleNotConnected,
                wholeDiskIdentifier: nil,
                apfsContainerIdentifier: nil,
                physicalStoreIdentifier: nil,
                knownVolumeNames: [],
                mountedVolumeNames: [],
                physicalDiskIdentifiersConsidered: []
            )
        }

        guard targetVolumes.allSatisfy({ configuration.acceptsStableIdentifier($0.stableIdentifier, forVolumeName: $0.name) }) else {
            return unexpectedResolution(for: targetVolumes)
        }

        let candidates = targetVolumes.compactMap { resolvedCandidate(for: $0, in: inventory) }
        guard candidates.count == targetVolumes.count else {
            return unexpectedResolution(for: targetVolumes)
        }

        let physicalWholeDisks = Set(candidates.map(\.physicalDisk.wholeDiskIdentifier))
        if physicalWholeDisks.count > 1 {
            return T7TargetResolution(
                outcome: .unsafeTargetMultipleDisks,
                reason: .unsafeTargetMultipleDisks,
                wholeDiskIdentifier: nil,
                apfsContainerIdentifier: nil,
                physicalStoreIdentifier: nil,
                knownVolumeNames: orderedVolumeNames(from: targetVolumes),
                mountedVolumeNames: orderedVolumeNames(from: targetVolumes.filter { $0.mountPoint != nil }),
                physicalDiskIdentifiersConsidered: Array(physicalWholeDisks).sorted()
            )
        }

        guard candidates.allSatisfy({ configuration.acceptsAPFSContainerStableIdentifier($0.apfsContainer?.stableIdentifier) }),
              candidates.allSatisfy({ configuration.acceptsPhysicalStoreStableIdentifier($0.physicalStore?.stableIdentifier) }),
              candidates.allSatisfy({ configuration.acceptsSamsungMetadata(for: $0.physicalDisk) })
        else {
            return unexpectedResolution(for: targetVolumes, candidates: candidates)
        }

        guard let targetDisk = candidates.first?.physicalDisk else {
            return unexpectedResolution(for: targetVolumes, candidates: candidates)
        }

        if targetDisk.isInternal || !targetDisk.isExternal {
            return resolution(
                outcome: .unsafeTargetInternalDisk,
                reason: .unsafeTargetInternalDisk,
                candidates: candidates,
                volumes: targetVolumes
            )
        }

        let mountedVolumes = targetVolumes.filter { $0.mountPoint != nil }
        if mountedVolumes.isEmpty {
            return resolution(
                outcome: .idleAlreadyUnmounted,
                reason: .idleAlreadyUnmounted,
                candidates: candidates,
                volumes: targetVolumes
            )
        }

        return resolution(
            outcome: .readyToEject,
            reason: nil,
            candidates: candidates,
            volumes: targetVolumes
        )
    }

    private func resolvedCandidate(for volume: T7VolumeEvidence, in inventory: T7DiskInventory) -> ResolvedCandidate? {
        guard let container = inventory.apfsContainer(forStableIdentifier: volume.apfsContainerStableIdentifier),
              let containerStoreIdentifier = container.physicalStoreStableIdentifier,
              volume.physicalStoreStableIdentifier.map({ identifiersMatch($0, containerStoreIdentifier) }) ?? true,
              let store = inventory.physicalStore(forStableIdentifier: containerStoreIdentifier),
              identifiersMatch(store.stableIdentifier, containerStoreIdentifier),
              volume.parentWholeDiskIdentifier.map({ identifiersMatch($0, container.diskIdentifier) }) ?? true
        else {
            return nil
        }

        guard let physicalDisk = inventory.physicalDisk(forWholeDiskIdentifier: store.wholeDiskIdentifier)
        else {
            return nil
        }

        return ResolvedCandidate(
            volume: volume,
            apfsContainer: container,
            physicalStore: store,
            physicalDisk: physicalDisk
        )
    }

    private func resolveKnownUnmountedTarget(in inventory: T7DiskInventory) -> ResolvedCandidate? {
        let matchingStores = inventory.physicalStores.filter {
            configuration.acceptsPhysicalStoreStableIdentifier($0.stableIdentifier)
        }
        guard matchingStores.count == 1,
              let store = matchingStores.first,
              let physicalDisk = inventory.physicalDisk(forWholeDiskIdentifier: store.wholeDiskIdentifier),
              configuration.acceptsSamsungMetadata(for: physicalDisk)
        else {
            return nil
        }

        let container = inventory.apfsContainers.first {
            identifiersMatch($0.physicalStoreStableIdentifier, store.stableIdentifier)
                && configuration.acceptsAPFSContainerStableIdentifier($0.stableIdentifier)
        }

        return ResolvedCandidate(
            volume: nil,
            apfsContainer: container,
            physicalStore: store,
            physicalDisk: physicalDisk
        )
    }

    private func resolution(
        outcome: T7TargetResolutionOutcome,
        reason: T7EjectReason?,
        candidates: [ResolvedCandidate],
        volumes: [T7VolumeEvidence]
    ) -> T7TargetResolution {
        let representative = candidates.first
        let knownVolumes = orderedVolumeNames(from: volumes)
        let mountedVolumes = orderedVolumeNames(from: volumes.filter { $0.mountPoint != nil })

        return T7TargetResolution(
            outcome: outcome,
            reason: reason,
            wholeDiskIdentifier: representative?.physicalDisk.wholeDiskIdentifier,
            apfsContainerIdentifier: representative?.apfsContainer?.diskIdentifier,
            physicalStoreIdentifier: representative?.physicalStore?.diskIdentifier,
            knownVolumeNames: knownVolumes,
            mountedVolumeNames: mountedVolumes,
            physicalDiskIdentifiersConsidered: Array(Set(candidates.map(\.physicalDisk.wholeDiskIdentifier))).sorted()
        )
    }

    private func unexpectedResolution(
        for volumes: [T7VolumeEvidence],
        candidates: [ResolvedCandidate] = []
    ) -> T7TargetResolution {
        T7TargetResolution(
            outcome: .unexpectedError,
            reason: .unexpectedError,
            wholeDiskIdentifier: candidates.first?.physicalDisk.wholeDiskIdentifier,
            apfsContainerIdentifier: candidates.first?.apfsContainer?.diskIdentifier,
            physicalStoreIdentifier: candidates.first?.physicalStore?.diskIdentifier,
            knownVolumeNames: orderedVolumeNames(from: volumes),
            mountedVolumeNames: orderedVolumeNames(from: volumes.filter { $0.mountPoint != nil }),
            physicalDiskIdentifiersConsidered: Array(Set(candidates.map(\.physicalDisk.wholeDiskIdentifier))).sorted()
        )
    }

    private func identifiersMatch(_ lhs: String?, _ rhs: String?) -> Bool {
        guard let lhs, let rhs else {
            return false
        }
        return normalizedIdentifier(lhs) == normalizedIdentifier(rhs)
    }

    private func normalizedIdentifier(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private func orderedVolumeNames(from volumes: [T7VolumeEvidence]) -> [String] {
        let names = Set(volumes.map(\.name))
        return configuration.targetVolumeNames.filter { names.contains($0) }
    }

    private struct ResolvedCandidate {
        let volume: T7VolumeEvidence?
        let apfsContainer: T7APFSContainerEvidence?
        let physicalStore: T7PhysicalStoreEvidence?
        let physicalDisk: T7PhysicalDiskEvidence
    }
}

private extension T7DiskInventory {
    func apfsContainer(forStableIdentifier stableIdentifier: String?) -> T7APFSContainerEvidence? {
        guard let stableIdentifier else {
            return nil
        }
        return apfsContainers.first { $0.stableIdentifier.caseInsensitiveCompare(stableIdentifier) == .orderedSame }
    }

    func physicalStore(forStableIdentifier stableIdentifier: String?) -> T7PhysicalStoreEvidence? {
        guard let stableIdentifier else {
            return nil
        }
        return physicalStores.first { $0.stableIdentifier.caseInsensitiveCompare(stableIdentifier) == .orderedSame }
    }

    func physicalDisk(forWholeDiskIdentifier wholeDiskIdentifier: String) -> T7PhysicalDiskEvidence? {
        physicalDisks.first { $0.wholeDiskIdentifier == wholeDiskIdentifier }
    }
}
