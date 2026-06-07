import DiskArbitration
import Foundation

protocol T7DiskArbitrationClock {
    func now() -> Date
}

struct T7SystemDiskArbitrationClock: T7DiskArbitrationClock {
    func now() -> Date {
        Date()
    }
}

struct T7DiskArbitrationEjectRequest: Equatable {
    let wholeDiskIdentifier: String
    let apfsContainerIdentifier: String?
    let mountedVolumeNames: [String]
    let timeMachineWasRunning: Bool
    let timeMachineStopped: Bool
}

struct T7DiskArbitrationDissenter: Equatable {
    let status: Int
    let message: String?
}

enum T7DiskArbitrationOperationResult: Equatable {
    case success
    case dissented(T7DiskArbitrationDissenter)
}

struct T7MountedVolumeEvidence: Equatable {
    let name: String
    let mountPath: String?
    let wholeDiskIdentifier: String?
    let stableIdentifier: String?
}

protocol T7MountedVolumeProviding {
    func mountedVolumes() -> [T7MountedVolumeEvidence]
}

protocol T7DiskArbitrationOperating {
    func unmountWholeDisk(_ wholeDiskIdentifier: String) async -> T7DiskArbitrationOperationResult
    func ejectWholeDisk(_ wholeDiskIdentifier: String) async -> T7DiskArbitrationOperationResult
    func remainingMountedVolumes(
        named targetVolumeNames: [String],
        onWholeDisk wholeDiskIdentifier: String
    ) async -> [String]
}

protocol T7DiskUtilEjectFallbacking: AnyObject {
    func ejectWholeDisk(_ wholeDiskIdentifier: String) async -> T7DiskArbitrationOperationResult
}

struct T7DiskArbitrationEjector {
    private static let diskArbitrationUnsupportedEjectStatus = 49_168

    private let operation: any T7DiskArbitrationOperating
    private let diskUtilFallback: any T7DiskUtilEjectFallbacking
    private let clock: any T7DiskArbitrationClock

    init(
        operation: any T7DiskArbitrationOperating = T7DiskArbitrationSessionOperation(),
        diskUtilFallback: any T7DiskUtilEjectFallbacking = T7DiskUtilEjectFallback(),
        clock: any T7DiskArbitrationClock = T7SystemDiskArbitrationClock()
    ) {
        self.operation = operation
        self.diskUtilFallback = diskUtilFallback
        self.clock = clock
    }

    func eject(_ request: T7DiskArbitrationEjectRequest) async -> T7EjectResult {
        let startedAt = clock.now()
        let unmountResult = await operation.unmountWholeDisk(request.wholeDiskIdentifier)

        switch unmountResult {
        case .success:
            return await finishAfterSuccessfulUnmount(request: request, startedAt: startedAt)
        case .dissented(let dissenter):
            let remaining = await operation.remainingMountedVolumes(
                named: request.mountedVolumeNames,
                onWholeDisk: request.wholeDiskIdentifier
            )
            return result(
                status: .failed,
                reason: unmountFailureReason(for: dissenter),
                request: request,
                remainingMountedVolumes: remaining,
                dissenter: dissenter,
                startedAt: startedAt
            )
        }
    }

    private func finishAfterSuccessfulUnmount(
        request: T7DiskArbitrationEjectRequest,
        startedAt: Date
    ) async -> T7EjectResult {
        let ejectResult = await operation.ejectWholeDisk(request.wholeDiskIdentifier)
        let remaining = await operation.remainingMountedVolumes(
            named: request.mountedVolumeNames,
            onWholeDisk: request.wholeDiskIdentifier
        )

        switch ejectResult {
        case .success:
            return result(
                status: .success,
                reason: nil,
                request: request,
                remainingMountedVolumes: remaining,
                dissenter: nil,
                startedAt: startedAt
            )
        case .dissented(let dissenter):
            if shouldUseDiskUtilFallback(after: dissenter) {
                let fallbackResult = await diskUtilFallback.ejectWholeDisk(request.wholeDiskIdentifier)
                let fallbackRemaining = await operation.remainingMountedVolumes(
                    named: request.mountedVolumeNames,
                    onWholeDisk: request.wholeDiskIdentifier
                )

                if case .success = fallbackResult, fallbackRemaining.isEmpty {
                    return result(
                        status: .success,
                        reason: nil,
                        request: request,
                        remainingMountedVolumes: fallbackRemaining,
                        dissenter: nil,
                        startedAt: startedAt
                    )
                }
            }

            return result(
                status: .failed,
                reason: .unmountSucceededEjectFailed,
                request: request,
                remainingMountedVolumes: remaining,
                dissenter: dissenter,
                startedAt: startedAt
            )
        }
    }

    private func shouldUseDiskUtilFallback(after dissenter: T7DiskArbitrationDissenter) -> Bool {
        dissenter.status == Self.diskArbitrationUnsupportedEjectStatus
    }

    private func result(
        status: T7EjectStatus,
        reason: T7EjectReason?,
        request: T7DiskArbitrationEjectRequest,
        remainingMountedVolumes: [String],
        dissenter: T7DiskArbitrationDissenter?,
        startedAt: Date
    ) -> T7EjectResult {
        T7EjectResult(
            status: status,
            reason: reason,
            action: .safeEject,
            wholeDisk: request.wholeDiskIdentifier,
            apfsContainer: request.apfsContainerIdentifier,
            volumes: request.mountedVolumeNames,
            timeMachineWasRunning: request.timeMachineWasRunning,
            timeMachineStopped: request.timeMachineStopped,
            remainingMountedVolumes: remainingMountedVolumes,
            dissenterStatus: dissenter?.status,
            dissenterMessage: dissenter?.message,
            startedAt: startedAt,
            endedAt: clock.now(),
            message: T7EjectResult.message(for: status, reason: reason)
        )
    }

    private func unmountFailureReason(for dissenter: T7DiskArbitrationDissenter) -> T7EjectReason {
        if dissenter.status == kDAReturnBusy {
            return .diskBusy
        }

        let message = dissenter.message?.lowercased() ?? ""
        if message.contains("busy") || message.contains("in use") {
            return .diskBusy
        }

        return .diskArbitrationDissented
    }
}

final class T7DiskUtilEjectFallback: T7DiskUtilEjectFallbacking {
    private let timeout: TimeInterval

    init(timeout: TimeInterval = 60) {
        self.timeout = timeout
    }

    func ejectWholeDisk(_ wholeDiskIdentifier: String) async -> T7DiskArbitrationOperationResult {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
            process.arguments = ["eject", Self.bsdName(from: wholeDiskIdentifier)]

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            let box = T7DiskUtilEjectProcessBox(
                process: process,
                outputPipe: outputPipe,
                errorPipe: errorPipe,
                continuation: continuation
            )

            process.terminationHandler = { _ in
                box.finishFromProcessTermination()
            }

            do {
                try process.run()
            } catch {
                box.finish(.dissented(T7DiskArbitrationDissenter(
                    status: Int(kDAReturnError),
                    message: "diskutil eject could not start: \(error)"
                )))
                return
            }

            let timeout = timeout
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
                box.terminateAfterTimeout(timeout)
            }
        }
    }

    private static func bsdName(from identifier: String) -> String {
        if identifier.hasPrefix("/dev/") {
            return String(identifier.dropFirst("/dev/".count))
        }
        return identifier
    }
}

private final class T7DiskUtilEjectProcessBox: @unchecked Sendable {
    private let process: Process
    private let outputPipe: Pipe
    private let errorPipe: Pipe
    private let continuation: CheckedContinuation<T7DiskArbitrationOperationResult, Never>
    private let lock = NSLock()
    private var hasFinished = false
    private var pendingTimeout: TimeInterval?

    init(
        process: Process,
        outputPipe: Pipe,
        errorPipe: Pipe,
        continuation: CheckedContinuation<T7DiskArbitrationOperationResult, Never>
    ) {
        self.process = process
        self.outputPipe = outputPipe
        self.errorPipe = errorPipe
        self.continuation = continuation
    }

    func finishFromProcessTermination() {
        let status = process.terminationStatus
        let stdout = Self.string(from: outputPipe)
        let stderr = Self.string(from: errorPipe)

        if let timeout = takePendingTimeout() {
            finishAfterTimeoutTermination(timeout, status: status, stderr: stderr)
            return
        }

        if status == 0 {
            finish(.success)
        } else {
            let details = [stderr, stdout]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            finish(.dissented(T7DiskArbitrationDissenter(
                status: Int(status),
                message: details.isEmpty ? "diskutil eject failed with status \(status)." : details
            )))
        }
    }

    func terminateAfterTimeout(_ timeout: TimeInterval) {
        lock.lock()
        let shouldTerminate = !hasFinished
        if shouldTerminate {
            pendingTimeout = timeout
        }
        lock.unlock()

        guard shouldTerminate else {
            return
        }

        if process.isRunning {
            process.terminate()
        }
    }

    func finish(_ result: T7DiskArbitrationOperationResult) {
        lock.lock()
        guard !hasFinished else {
            lock.unlock()
            return
        }
        hasFinished = true
        lock.unlock()

        continuation.resume(returning: result)
    }

    private func takePendingTimeout() -> TimeInterval? {
        lock.lock()
        let timeout = pendingTimeout
        pendingTimeout = nil
        lock.unlock()
        return timeout
    }

    private func finishAfterTimeoutTermination(_ timeout: TimeInterval, status: Int32, stderr: String) {
        let trimmedStderr = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = trimmedStderr.isEmpty ? "" : " \(trimmedStderr)"
        finish(.dissented(T7DiskArbitrationDissenter(
            status: Int(kDAReturnBusy),
            message: "diskutil eject timed out after \(String(format: "%.3f", timeout)) seconds; terminated with status \(status).\(suffix)"
        )))
    }

    private static func string(from pipe: Pipe) -> String {
        String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
}

final class T7DiskArbitrationSessionOperation: T7DiskArbitrationOperating {
    private let queue: DispatchQueue
    private let mountedVolumeProvider: any T7MountedVolumeProviding
    private let targetStableIdentifiersByName: [String: Set<String>]
    private let timeout: TimeInterval

    init(
        queue: DispatchQueue = DispatchQueue(label: "com.maldaze.t7.disk-arbitration"),
        fileManager: FileManager = .default,
        timeout: TimeInterval = 30,
        mountedVolumeProvider: (any T7MountedVolumeProviding)? = nil,
        targetStableIdentifiersByName: [String: Set<String>] = T7TargetResolverConfiguration
            .samsungT7ShieldSeed
            .volumeStableIdentifiersByName
    ) {
        self.queue = queue
        self.mountedVolumeProvider = mountedVolumeProvider ?? T7SystemMountedVolumeProvider(fileManager: fileManager)
        self.targetStableIdentifiersByName = targetStableIdentifiersByName.mapValues { identifiers in
            Set(identifiers.map(Self.normalizedStableIdentifier))
        }
        self.timeout = timeout
    }

    func unmountWholeDisk(_ wholeDiskIdentifier: String) async -> T7DiskArbitrationOperationResult {
        await perform(wholeDiskIdentifier: wholeDiskIdentifier) { disk, context in
            DADiskUnmount(
                disk,
                UInt32(kDADiskUnmountOptionWhole),
                T7DiskArbitrationCallbackBox.unmountCallback,
                context
            )
        }
    }

    func ejectWholeDisk(_ wholeDiskIdentifier: String) async -> T7DiskArbitrationOperationResult {
        await perform(wholeDiskIdentifier: wholeDiskIdentifier) { disk, context in
            DADiskEject(
                disk,
                UInt32(kDADiskEjectOptionDefault),
                T7DiskArbitrationCallbackBox.ejectCallback,
                context
            )
        }
    }

    func remainingMountedVolumes(
        named targetVolumeNames: [String],
        onWholeDisk wholeDiskIdentifier: String
    ) async -> [String] {
        let targetNames = Set(targetVolumeNames)
        let targetWholeDisk = Self.normalizedDiskIdentifier(wholeDiskIdentifier)
        let expectedMountPaths = Set(targetVolumeNames.map(Self.defaultMountPath(forVolumeNamed:)))
        let matchingVolumes = mountedVolumeProvider.mountedVolumes().filter { volume in
            guard targetNames.contains(volume.name) else {
                return false
            }
            if let volumeWholeDisk = volume.wholeDiskIdentifier {
                if Self.normalizedDiskIdentifier(volumeWholeDisk) == targetWholeDisk {
                    return true
                }
                return matchesTargetStableIdentifier(volume)
            }
            if matchesTargetStableIdentifier(volume) {
                return true
            }
            if hasStableIdentifierExpectation(for: volume.name) {
                return false
            }
            if let mountPath = volume.mountPath {
                return expectedMountPaths.contains(Self.normalizedMountPath(mountPath))
            }
            return false
        }
        let matchingNames = Set(matchingVolumes.map(\.name))
        return targetVolumeNames.filter { matchingNames.contains($0) }
    }

    private func matchesTargetStableIdentifier(_ volume: T7MountedVolumeEvidence) -> Bool {
        guard let stableIdentifier = volume.stableIdentifier,
              let expectedIdentifiers = targetStableIdentifiersByName[volume.name],
              !expectedIdentifiers.isEmpty
        else {
            return false
        }

        return expectedIdentifiers.contains(Self.normalizedStableIdentifier(stableIdentifier))
    }

    private func hasStableIdentifierExpectation(for volumeName: String) -> Bool {
        guard let expectedIdentifiers = targetStableIdentifiersByName[volumeName] else {
            return false
        }
        return !expectedIdentifiers.isEmpty
    }

    private func perform(
        wholeDiskIdentifier: String,
        start: @escaping (DADisk, UnsafeMutableRawPointer) -> Void
    ) async -> T7DiskArbitrationOperationResult {
        await withCheckedContinuation { continuation in
            guard let session = DASessionCreate(nil) else {
                continuation.resume(returning: .dissented(T7DiskArbitrationDissenter(
                    status: Int(kDAReturnError),
                    message: "Unable to create Disk Arbitration session."
                )))
                return
            }

            DASessionSetDispatchQueue(session, queue)

            let bsdName = Self.bsdName(from: wholeDiskIdentifier)
            guard let disk = bsdName.withCString({ DADiskCreateFromBSDName(nil, session, $0) }) else {
                DASessionSetDispatchQueue(session, nil)
                continuation.resume(returning: .dissented(T7DiskArbitrationDissenter(
                    status: Int(kDAReturnNotFound),
                    message: "Unable to create Disk Arbitration disk for \(wholeDiskIdentifier)."
                )))
                return
            }

            let box = T7DiskArbitrationCallbackBox(
                continuation: continuation,
                session: session
            )
            let context = T7DiskArbitrationCallbackBox.retainedContext(for: box)

            queue.asyncAfter(deadline: .now() + timeout) {
                box.finish(.dissented(T7DiskArbitrationDissenter(
                    status: Int(kDAReturnBusy),
                    message: "Disk Arbitration operation timed out."
                )))
            }

            start(disk, context)
        }
    }

    private static func bsdName(from identifier: String) -> String {
        if identifier.hasPrefix("/dev/") {
            return String(identifier.dropFirst("/dev/".count))
        }
        return identifier
    }

    private static func normalizedDiskIdentifier(_ identifier: String) -> String {
        bsdName(from: identifier).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedStableIdentifier(_ identifier: String) -> String {
        identifier.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private static func defaultMountPath(forVolumeNamed name: String) -> String {
        normalizedMountPath(URL(fileURLWithPath: "/Volumes").appendingPathComponent(name).path)
    }

    private static func normalizedMountPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }
}

private final class T7DiskArbitrationCallbackBox: @unchecked Sendable {
    private static let registryLock = NSLock()
    nonisolated(unsafe) private static var nextContextID: UInt = 1
    nonisolated(unsafe) private static var retainedBoxes: [UInt: T7DiskArbitrationCallbackBox] = [:]

    private let continuation: CheckedContinuation<T7DiskArbitrationOperationResult, Never>
    private let session: DASession
    private let lock = NSLock()
    private var context: UnsafeMutableRawPointer?
    private var hasFinished = false

    init(
        continuation: CheckedContinuation<T7DiskArbitrationOperationResult, Never>,
        session: DASession
    ) {
        self.continuation = continuation
        self.session = session
    }

    static func retainedContext(for box: T7DiskArbitrationCallbackBox) -> UnsafeMutableRawPointer {
        registryLock.lock()
        let contextID = nextContextID
        nextContextID += 1
        let context = UnsafeMutableRawPointer(bitPattern: contextID)!
        box.context = context
        retainedBoxes[contextID] = box
        registryLock.unlock()
        return context
    }

    static func unregister(context: UnsafeMutableRawPointer) {
        registryLock.lock()
        retainedBoxes[UInt(bitPattern: context)] = nil
        registryLock.unlock()
    }

    private static func box(for context: UnsafeMutableRawPointer) -> T7DiskArbitrationCallbackBox? {
        registryLock.lock()
        let box = retainedBoxes[UInt(bitPattern: context)]
        registryLock.unlock()
        return box
    }

    func finish(_ result: T7DiskArbitrationOperationResult) {
        lock.lock()
        guard !hasFinished else {
            lock.unlock()
            return
        }
        hasFinished = true
        let context = context
        self.context = nil
        lock.unlock()

        DASessionSetDispatchQueue(session, nil)
        if let context {
            Self.unregister(context: context)
        }
        continuation.resume(returning: result)
    }

    static let unmountCallback: DADiskUnmountCallback = { _, dissenter, context in
        complete(context: context, dissenter: dissenter)
    }

    static let ejectCallback: DADiskEjectCallback = { _, dissenter, context in
        complete(context: context, dissenter: dissenter)
    }

    private static func complete(context: UnsafeMutableRawPointer?, dissenter: DADissenter?) {
        guard let context else {
            return
        }

        guard let box = box(for: context) else {
            return
        }
        box.finish(result(from: dissenter))
    }

    private static func result(from dissenter: DADissenter?) -> T7DiskArbitrationOperationResult {
        guard let dissenter else {
            return .success
        }

        return .dissented(T7DiskArbitrationDissenter(
            status: Int(DADissenterGetStatus(dissenter)),
            message: DADissenterGetStatusString(dissenter) as String?
        ))
    }
}

private struct T7SystemMountedVolumeProvider: T7MountedVolumeProviding {
    let fileManager: FileManager

    func mountedVolumes() -> [T7MountedVolumeEvidence] {
        let mountedVolumeKeys: Set<URLResourceKey> = [.volumeNameKey]
        let mountedURLs = fileManager.mountedVolumeURLs(
            includingResourceValuesForKeys: Array(mountedVolumeKeys),
            options: []
        ) ?? []

        return mountedURLs.map { url in
            let resourceValues = try? url.resourceValues(forKeys: mountedVolumeKeys)
            let metadata = T7DiskArbitrationVolumeMetadata.evidence(for: url)
            return T7MountedVolumeEvidence(
                name: resourceValues?.volumeName ?? url.lastPathComponent,
                mountPath: url.path,
                wholeDiskIdentifier: metadata.wholeDiskIdentifier,
                stableIdentifier: metadata.stableIdentifier
            )
        }
    }
}

private enum T7DiskArbitrationVolumeMetadata {
    static func evidence(for volumeURL: URL) -> (wholeDiskIdentifier: String?, stableIdentifier: String?) {
        guard let session = DASessionCreate(nil),
              let disk = DADiskCreateFromVolumePath(nil, session, volumeURL as CFURL)
        else {
            return (nil, nil)
        }

        let description = DADiskCopyDescription(disk) as? [String: Any]
        let stableIdentifier = stableIdentifier(from: description?[kDADiskDescriptionVolumeUUIDKey as String])

        let wholeDisk = DADiskCopyWholeDisk(disk) ?? disk
        let wholeDiskDescription = DADiskCopyDescription(wholeDisk) as? [String: Any]
        let wholeDiskIdentifier = wholeDiskDescription?[kDADiskDescriptionMediaBSDNameKey as String] as? String

        return (wholeDiskIdentifier, stableIdentifier)
    }

    private static func stableIdentifier(from value: Any?) -> String? {
        if let uuid = value as? UUID {
            return uuid.uuidString
        }
        if let value {
            let cfValue = value as CFTypeRef
            if CFGetTypeID(cfValue) == CFUUIDGetTypeID() {
                let uuid = unsafeBitCast(cfValue, to: CFUUID.self)
                if let uuidString = CFUUIDCreateString(nil, uuid) {
                    return uuidString as String
                }
            }
        }
        if let string = value as? String {
            return string
        }
        return nil
    }
}
