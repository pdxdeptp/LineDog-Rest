import Foundation

protocol T7DiskInventoryProviding {
    func inventory() throws -> any T7DiskInventory
}

protocol T7TimeMachinePreparing {
    func prepareForEject() async -> T7TimeMachinePreparationResult
}

protocol T7DiskArbitrationEjecting {
    func eject(_ request: T7DiskArbitrationEjectRequest) async -> T7EjectResult
}

protocol T7EjectHelperClock {
    func now() -> Date
}

protocol T7EjectHelperRunning {
    func run() async throws -> T7EjectResult
}

extension T7TimeMachineController: T7TimeMachinePreparing {}

extension T7DiskArbitrationEjector: T7DiskArbitrationEjecting {}

struct T7SystemEjectHelperClock: T7EjectHelperClock {
    func now() -> Date {
        Date()
    }
}

struct T7EjectHelperRunner: T7EjectHelperRunning {
    private let inventoryProvider: any T7DiskInventoryProviding
    private let resolver: T7TargetResolver
    private let timeMachinePreparer: any T7TimeMachinePreparing
    private let ejector: any T7DiskArbitrationEjecting
    private let clock: any T7EjectHelperClock

    init(
        inventoryProvider: any T7DiskInventoryProviding,
        resolver: T7TargetResolver = T7TargetResolver(configuration: .samsungT7ShieldSeed),
        timeMachinePreparer: any T7TimeMachinePreparing,
        ejector: any T7DiskArbitrationEjecting,
        clock: any T7EjectHelperClock = T7SystemEjectHelperClock()
    ) {
        self.inventoryProvider = inventoryProvider
        self.resolver = resolver
        self.timeMachinePreparer = timeMachinePreparer
        self.ejector = ejector
        self.clock = clock
    }

    static func live() -> T7EjectHelperRunner {
        T7EjectHelperRunner(
            inventoryProvider: T7DiskUtilInventoryProvider(),
            timeMachinePreparer: T7TimeMachineController(),
            ejector: T7DiskArbitrationEjector()
        )
    }

    func run() async throws -> T7EjectResult {
        let startedAt = clock.now()

        let inventory: any T7DiskInventory
        do {
            inventory = try inventoryProvider.inventory()
        } catch {
            return result(
                status: .failed,
                reason: .unexpectedError,
                wholeDisk: nil,
                apfsContainer: nil,
                volumes: [],
                timeMachineWasRunning: false,
                timeMachineStopped: false,
                startedAt: startedAt,
                diagnostic: String(describing: error)
            )
        }

        let resolution = resolver.resolve(in: inventory)

        switch resolution.outcome {
        case .idleNotConnected:
            return result(
                status: .idle,
                reason: .idleNotConnected,
                resolution: resolution,
                volumes: [],
                startedAt: startedAt
            )
        case .idleAlreadyUnmounted:
            return result(
                status: .idle,
                reason: .idleAlreadyUnmounted,
                resolution: resolution,
                volumes: resolution.knownVolumeNames,
                startedAt: startedAt
            )
        case .unsafeTargetMultipleDisks, .unsafeTargetInternalDisk, .unexpectedError:
            return result(
                status: .failed,
                reason: resolution.reason ?? .unexpectedError,
                resolution: resolution,
                volumes: failureVolumeNames(for: resolution),
                remainingMountedVolumes: resolution.mountedVolumeNames,
                startedAt: startedAt
            )
        case .readyToEject:
            return await ejectReadyTarget(resolution, startedAt: startedAt)
        }
    }

    private func ejectReadyTarget(
        _ resolution: T7TargetResolution,
        startedAt: Date
    ) async -> T7EjectResult {
        guard let wholeDiskIdentifier = resolution.wholeDiskIdentifier else {
            return result(
                status: .failed,
                reason: .unexpectedError,
                resolution: resolution,
                volumes: resolution.mountedVolumeNames,
                remainingMountedVolumes: resolution.mountedVolumeNames,
                startedAt: startedAt
            )
        }

        let preparation = await timeMachinePreparer.prepareForEject()
        guard preparation.canProceed else {
            return result(
                status: .failed,
                reason: preparation.reason ?? .unexpectedError,
                resolution: resolution,
                volumes: resolution.mountedVolumeNames,
                remainingMountedVolumes: resolution.mountedVolumeNames,
                timeMachineWasRunning: preparation.timeMachineWasRunning,
                timeMachineStopped: preparation.timeMachineStopped,
                startedAt: startedAt,
                diagnostic: preparation.diagnostic
            )
        }

        let request = T7DiskArbitrationEjectRequest(
            wholeDiskIdentifier: wholeDiskIdentifier,
            apfsContainerIdentifier: resolution.apfsContainerIdentifier,
            mountedVolumeNames: resolution.mountedVolumeNames,
            timeMachineWasRunning: preparation.timeMachineWasRunning,
            timeMachineStopped: preparation.timeMachineStopped
        )
        return await ejector.eject(request)
    }

    private func failureVolumeNames(for resolution: T7TargetResolution) -> [String] {
        if !resolution.knownVolumeNames.isEmpty {
            return resolution.knownVolumeNames
        }
        return resolution.mountedVolumeNames
    }

    private func result(
        status: T7EjectStatus,
        reason: T7EjectReason?,
        resolution: T7TargetResolution,
        volumes: [String],
        remainingMountedVolumes: [String] = [],
        timeMachineWasRunning: Bool = false,
        timeMachineStopped: Bool = false,
        startedAt: Date,
        diagnostic: String? = nil
    ) -> T7EjectResult {
        result(
            status: status,
            reason: reason,
            wholeDisk: resolution.wholeDiskIdentifier,
            apfsContainer: resolution.apfsContainerIdentifier,
            volumes: volumes,
            remainingMountedVolumes: remainingMountedVolumes,
            timeMachineWasRunning: timeMachineWasRunning,
            timeMachineStopped: timeMachineStopped,
            startedAt: startedAt,
            diagnostic: diagnostic
        )
    }

    private func result(
        status: T7EjectStatus,
        reason: T7EjectReason?,
        wholeDisk: String?,
        apfsContainer: String?,
        volumes: [String],
        remainingMountedVolumes: [String] = [],
        timeMachineWasRunning: Bool,
        timeMachineStopped: Bool,
        startedAt: Date,
        diagnostic: String? = nil
    ) -> T7EjectResult {
        T7EjectResult(
            status: status,
            reason: reason,
            action: .safeEject,
            wholeDisk: wholeDisk,
            apfsContainer: apfsContainer,
            volumes: volumes,
            timeMachineWasRunning: timeMachineWasRunning,
            timeMachineStopped: timeMachineStopped,
            remainingMountedVolumes: remainingMountedVolumes,
            dissenterStatus: nil,
            dissenterMessage: diagnostic,
            startedAt: startedAt,
            endedAt: clock.now(),
            message: T7EjectResult.message(for: status, reason: reason)
        )
    }
}

enum T7EjectHelperMain {
    typealias OutputWriter = (String) throws -> Void

    static func run(
        runner: any T7EjectHelperRunning,
        stdout: OutputWriter = T7EjectHelperMain.writeStdout,
        stderr: OutputWriter = T7EjectHelperMain.writeStderr
    ) async -> Int32 {
        do {
            let result = try await runner.run()
            try stdout(try result.stdoutJSONString() + "\n")
            return 0
        } catch {
            let now = Date()
            let result = T7EjectResult(
                status: .failed,
                reason: .unexpectedError,
                action: .safeEject,
                wholeDisk: nil,
                apfsContainer: nil,
                volumes: [],
                timeMachineWasRunning: false,
                timeMachineStopped: false,
                remainingMountedVolumes: [],
                dissenterStatus: nil,
                dissenterMessage: String(describing: error),
                startedAt: now,
                endedAt: Date(),
                message: T7EjectResult.message(for: .failed, reason: .unexpectedError)
            )
            try? stdout(try result.stdoutJSONString() + "\n")
            try? stderr("T7EjectHelper failed unexpectedly: \(error)\n")
            return 1
        }
    }

    private static func writeStdout(_ string: String) throws {
        FileHandle.standardOutput.write(Data(string.utf8))
    }

    private static func writeStderr(_ string: String) throws {
        FileHandle.standardError.write(Data(string.utf8))
    }
}
