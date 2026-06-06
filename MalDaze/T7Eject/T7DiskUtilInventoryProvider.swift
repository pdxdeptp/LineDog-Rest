import Foundation

struct T7DiskUtilCommand: Equatable {
    let executablePath: String
    let arguments: [String]
}

struct T7DiskUtilCommandResult: Equatable {
    let stdout: Data
    let stderr: Data
    let terminationStatus: Int32
}

enum T7DiskUtilInventoryProviderError: Error, Equatable {
    case commandFailed(arguments: [String], status: Int32, stderr: String)
    case commandTimedOut(arguments: [String], timeout: TimeInterval)
    case malformedPlist(arguments: [String])
}

struct T7DiskUtilInventoryProvider: T7DiskInventoryProviding {
    typealias CommandRunner = (T7DiskUtilCommand) throws -> T7DiskUtilCommandResult

    private static let executablePath = "/usr/sbin/diskutil"
    private static let processTimeout: TimeInterval = 10

    private let commandRunner: CommandRunner

    init(commandRunner: CommandRunner? = nil) {
        self.commandRunner = commandRunner ?? Self.runProcess
    }

    func inventory() throws -> any T7DiskInventory {
        let diskListPlist = try runPlist(arguments: ["list", "-plist"])
        let apfsListPlist = (try? runPlist(arguments: ["apfs", "list", "-plist"])) ?? [:]
        let identifiers = Self.diskIdentifiers(from: diskListPlist, apfsListPlist: apfsListPlist)

        var infoPlistsByIdentifier: [String: [String: Any]] = [:]
        for identifier in identifiers.sorted() {
            if let info = try? runPlist(arguments: ["info", "-plist", identifier]) {
                infoPlistsByIdentifier[identifier] = info
            }
        }

        return try Self.makeInventory(
            diskListPlist: diskListPlist,
            apfsListPlist: apfsListPlist,
            infoPlistsByIdentifier: infoPlistsByIdentifier
        )
    }

    static func makeInventory(
        diskListPlist: [String: Any],
        apfsListPlist: [String: Any],
        infoPlistsByIdentifier: [String: [String: Any]]
    ) throws -> T7StaticDiskInventory {
        let containers = apfsContainers(from: apfsListPlist)
        let stores = physicalStores(from: apfsListPlist, infoPlistsByIdentifier: infoPlistsByIdentifier)
        let volumes = volumeEvidence(from: apfsListPlist, infoPlistsByIdentifier: infoPlistsByIdentifier)
        let physicalDisks = physicalDisks(
            from: diskListPlist,
            stores: stores,
            infoPlistsByIdentifier: infoPlistsByIdentifier
        )

        return T7StaticDiskInventory(
            volumes: uniqueVolumes(volumes),
            apfsContainers: uniqueContainers(containers),
            physicalStores: uniqueStores(stores),
            physicalDisks: uniquePhysicalDisks(physicalDisks)
        )
    }

    private func runPlist(arguments: [String]) throws -> [String: Any] {
        let command = T7DiskUtilCommand(executablePath: Self.executablePath, arguments: arguments)
        let result = try commandRunner(command)
        guard result.terminationStatus == 0 else {
            throw T7DiskUtilInventoryProviderError.commandFailed(
                arguments: arguments,
                status: result.terminationStatus,
                stderr: String(data: result.stderr, encoding: .utf8) ?? ""
            )
        }

        guard
            let plist = try PropertyListSerialization.propertyList(
                from: result.stdout,
                options: [],
                format: nil
            ) as? [String: Any]
        else {
            throw T7DiskUtilInventoryProviderError.malformedPlist(arguments: arguments)
        }
        return plist
    }

    private static func runProcess(_ command: T7DiskUtilCommand) throws -> T7DiskUtilCommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command.executablePath)
        process.arguments = command.arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let terminationSemaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in
            terminationSemaphore.signal()
        }

        try process.run()
        if terminationSemaphore.wait(timeout: deadline(after: processTimeout)) == .timedOut {
            process.terminate()
            _ = terminationSemaphore.wait(timeout: deadline(after: 1))
            throw T7DiskUtilInventoryProviderError.commandTimedOut(
                arguments: command.arguments,
                timeout: processTimeout
            )
        }

        return T7DiskUtilCommandResult(
            stdout: stdoutPipe.fileHandleForReading.readDataToEndOfFile(),
            stderr: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
            terminationStatus: process.terminationStatus
        )
    }

    private static func deadline(after timeout: TimeInterval) -> DispatchTime {
        .now() + .milliseconds(Int(timeout * 1_000))
    }

    private static func diskIdentifiers(
        from diskListPlist: [String: Any],
        apfsListPlist: [String: Any]
    ) -> Set<String> {
        var identifiers = Set(stringArray(diskListPlist["AllDisks"]))

        for disk in dictionaryArray(diskListPlist["AllDisksAndPartitions"]) {
            appendDiskIdentifiers(from: disk, into: &identifiers)
        }

        for container in dictionaryArray(apfsListPlist["Containers"]) {
            identifiers.formUnion(strings(in: container, keys: ["ContainerReference", "DeviceIdentifier"]))
            for store in dictionaryArray(container["PhysicalStores"]) {
                identifiers.formUnion(strings(in: store, keys: ["DeviceIdentifier", "DiskIdentifier"]))
            }
            for volume in dictionaryArray(container["Volumes"]) {
                identifiers.formUnion(strings(in: volume, keys: ["DeviceIdentifier", "DiskIdentifier"]))
            }
        }

        return identifiers
    }

    private static func appendDiskIdentifiers(from dictionary: [String: Any], into identifiers: inout Set<String>) {
        identifiers.formUnion(strings(in: dictionary, keys: ["DeviceIdentifier", "DiskIdentifier"]))
        for partition in dictionaryArray(dictionary["Partitions"]) {
            appendDiskIdentifiers(from: partition, into: &identifiers)
        }
        for volume in dictionaryArray(dictionary["APFSVolumes"]) {
            appendDiskIdentifiers(from: volume, into: &identifiers)
        }
    }

    private static func apfsContainers(from apfsListPlist: [String: Any]) -> [T7APFSContainerEvidence] {
        dictionaryArray(apfsListPlist["Containers"]).compactMap { container in
            guard let stableIdentifier = string(in: container, keys: ["APFSContainerUUID", "ContainerUUID", "UUID"]) else {
                return nil
            }
            let stores = dictionaryArray(container["PhysicalStores"])
            return T7APFSContainerEvidence(
                stableIdentifier: stableIdentifier,
                diskIdentifier: string(in: container, keys: ["ContainerReference", "APFSContainerReference", "DeviceIdentifier"]),
                physicalStoreStableIdentifier: stores.compactMap(physicalStoreStableIdentifier).first
            )
        }
    }

    private static func physicalStores(
        from apfsListPlist: [String: Any],
        infoPlistsByIdentifier: [String: [String: Any]]
    ) -> [T7PhysicalStoreEvidence] {
        dictionaryArray(apfsListPlist["Containers"]).flatMap { container in
            dictionaryArray(container["PhysicalStores"]).compactMap { store in
                guard let stableIdentifier = physicalStoreStableIdentifier(from: store),
                      let diskIdentifier = string(in: store, keys: ["DeviceIdentifier", "DiskIdentifier"])
                else {
                    return nil
                }

                let info = infoPlistsByIdentifier[diskIdentifier] ?? [:]
                let wholeDiskIdentifier = string(in: info, keys: ["ParentWholeDisk", "WholeDisk", "MediaBSDName"])
                    ?? parentWholeDiskIdentifier(from: diskIdentifier)
                return T7PhysicalStoreEvidence(
                    stableIdentifier: stableIdentifier,
                    diskIdentifier: diskIdentifier,
                    wholeDiskIdentifier: wholeDiskIdentifier
                )
            }
        }
    }

    private static func volumeEvidence(
        from apfsListPlist: [String: Any],
        infoPlistsByIdentifier: [String: [String: Any]]
    ) -> [T7VolumeEvidence] {
        var volumes: [T7VolumeEvidence] = []

        for container in dictionaryArray(apfsListPlist["Containers"]) {
            let containerDiskIdentifier = string(in: container, keys: ["ContainerReference", "APFSContainerReference", "DeviceIdentifier"])
            let containerStableIdentifier = string(in: container, keys: ["APFSContainerUUID", "ContainerUUID", "UUID"])
            let storeStableIdentifier = dictionaryArray(container["PhysicalStores"])
                .compactMap(physicalStoreStableIdentifier)
                .first

            for volume in dictionaryArray(container["Volumes"]) {
                guard let name = string(in: volume, keys: ["Name", "VolumeName"]) else {
                    continue
                }
                let diskIdentifier = string(in: volume, keys: ["DeviceIdentifier", "DiskIdentifier"])
                volumes.append(
                    T7VolumeEvidence(
                        name: name,
                        stableIdentifier: string(in: volume, keys: ["APFSVolumeUUID", "VolumeUUID", "DiskUUID", "UUID"]),
                        diskIdentifier: diskIdentifier,
                        mountPoint: mountPoint(from: volume),
                        apfsRole: firstRole(from: volume),
                        parentWholeDiskIdentifier: containerDiskIdentifier,
                        apfsContainerStableIdentifier: containerStableIdentifier,
                        physicalStoreStableIdentifier: storeStableIdentifier
                    )
                )
            }
        }

        for (identifier, info) in infoPlistsByIdentifier where !volumes.contains(where: { $0.diskIdentifier == identifier }) {
            guard let name = string(in: info, keys: ["VolumeName", "Name"]) else {
                continue
            }
            volumes.append(
                T7VolumeEvidence(
                    name: name,
                    stableIdentifier: string(in: info, keys: ["VolumeUUID", "APFSVolumeUUID", "DiskUUID", "UUID"]),
                    diskIdentifier: identifier,
                    mountPoint: mountPoint(from: info),
                    apfsRole: firstRole(from: info),
                    parentWholeDiskIdentifier: string(in: info, keys: ["ParentWholeDisk", "APFSContainerReference"]),
                    apfsContainerStableIdentifier: string(in: info, keys: ["APFSContainerUUID", "ContainerUUID"]),
                    physicalStoreStableIdentifier: string(in: info, keys: ["APFSPhysicalStoreUUID", "PhysicalStoreUUID"])
                )
            )
        }

        return volumes
    }

    private static func physicalDisks(
        from diskListPlist: [String: Any],
        stores: [T7PhysicalStoreEvidence],
        infoPlistsByIdentifier: [String: [String: Any]]
    ) -> [T7PhysicalDiskEvidence] {
        var identifiers = Set(stores.map(\.wholeDiskIdentifier))
        identifiers.formUnion(stringArray(diskListPlist["AllDisks"]).filter { identifier in
            let info = infoPlistsByIdentifier[identifier] ?? [:]
            return bool(in: info, keys: ["WholeDisk"]) ?? !identifier.contains("s")
        })

        return identifiers.compactMap { identifier in
            guard let info = infoPlistsByIdentifier[identifier] else {
                return nil
            }
            let isInternal = bool(in: info, keys: ["Internal", "MediaInternal"]) ?? false
            let explicitlyExternal = bool(in: info, keys: ["External"])
            let isEjectable = bool(in: info, keys: ["Ejectable", "Removable"])
            let protocolName = string(in: info, keys: ["BusProtocol", "Protocol", "DeviceProtocol"])
            let hasExternalEvidence = explicitlyExternal == true
                || isEjectable == true
                || isExternalProtocol(protocolName)
            let isExternal = !isInternal && hasExternalEvidence

            return T7PhysicalDiskEvidence(
                stableIdentifier: string(in: info, keys: ["DiskUUID", "MediaUUID", "UUID", "IORegistryEntryName"]),
                wholeDiskIdentifier: identifier,
                isExternal: isExternal,
                isInternal: isInternal,
                protocolName: protocolName,
                mediaName: string(in: info, keys: ["MediaName", "MediaType", "DeviceName"]),
                model: string(in: info, keys: ["DeviceModel", "Model", "MediaModel"])
            )
        }
    }

    private static func physicalStoreStableIdentifier(from store: [String: Any]) -> String? {
        string(in: store, keys: ["APFSPhysicalStoreUUID", "PhysicalStoreUUID", "DiskUUID", "UUID"])
    }

    private static func isExternalProtocol(_ protocolName: String?) -> Bool {
        guard let protocolName else { return false }
        let normalized = protocolName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "usb" || normalized == "thunderbolt" || normalized == "firewire"
    }

    private static func parentWholeDiskIdentifier(from diskIdentifier: String) -> String {
        guard let range = diskIdentifier.range(of: #"s[0-9]+$"#, options: .regularExpression) else {
            return diskIdentifier
        }
        return String(diskIdentifier[..<range.lowerBound])
    }

    private static func mountPoint(from dictionary: [String: Any]) -> String? {
        string(in: dictionary, keys: ["MountPoint", "MountPointPath", "VolumePath"])
    }

    private static func firstRole(from dictionary: [String: Any]) -> String? {
        if let roles = stringArray(dictionary["Roles"]).first {
            return roles
        }
        return string(in: dictionary, keys: ["Role", "APFSVolumeRole"])
    }

    private static func string(in dictionary: [String: Any], keys: [String]) -> String? {
        for key in keys {
            guard let value = dictionary[key], !(value is NSNull) else {
                continue
            }
            if let string = value as? String {
                let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
            if let uuid = value as? UUID {
                return uuid.uuidString
            }
            if let convertible = value as? CustomStringConvertible {
                let string = convertible.description.trimmingCharacters(in: .whitespacesAndNewlines)
                if !string.isEmpty {
                    return string
                }
            }
        }
        return nil
    }

    private static func strings(in dictionary: [String: Any], keys: [String]) -> Set<String> {
        Set(keys.compactMap { key in
            string(in: dictionary, keys: [key])
        })
    }

    private static func bool(in dictionary: [String: Any], keys: [String]) -> Bool? {
        for key in keys {
            guard let value = dictionary[key], !(value is NSNull) else {
                continue
            }
            if let bool = value as? Bool {
                return bool
            }
            if let number = value as? NSNumber {
                return number.boolValue
            }
            if let string = value as? String {
                switch string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                case "yes", "true", "1":
                    return true
                case "no", "false", "0":
                    return false
                default:
                    continue
                }
            }
        }
        return nil
    }

    private static func stringArray(_ value: Any?) -> [String] {
        if let strings = value as? [String] {
            return strings
        }
        if let values = value as? [Any] {
            return values.compactMap { item in
                if let string = item as? String {
                    return string
                }
                return (item as? CustomStringConvertible)?.description
            }
        }
        if let string = value as? String {
            return [string]
        }
        return []
    }

    private static func dictionaryArray(_ value: Any?) -> [[String: Any]] {
        value as? [[String: Any]] ?? []
    }

    private static func uniqueVolumes(_ volumes: [T7VolumeEvidence]) -> [T7VolumeEvidence] {
        var seen = Set<String>()
        return volumes.filter { volume in
            let key = volume.diskIdentifier ?? "\(volume.name)-\(volume.stableIdentifier ?? "")"
            return seen.insert(key).inserted
        }
    }

    private static func uniqueContainers(_ containers: [T7APFSContainerEvidence]) -> [T7APFSContainerEvidence] {
        var seen = Set<String>()
        return containers.filter { seen.insert($0.stableIdentifier).inserted }
    }

    private static func uniqueStores(_ stores: [T7PhysicalStoreEvidence]) -> [T7PhysicalStoreEvidence] {
        var seen = Set<String>()
        return stores.filter { seen.insert($0.stableIdentifier).inserted }
    }

    private static func uniquePhysicalDisks(_ disks: [T7PhysicalDiskEvidence]) -> [T7PhysicalDiskEvidence] {
        var seen = Set<String>()
        return disks.filter { seen.insert($0.wholeDiskIdentifier).inserted }
    }
}
