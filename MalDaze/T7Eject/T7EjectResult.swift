import Foundation

enum T7EjectStatus: String, Codable, Equatable {
    case success
    case failed
    case idle
}

enum T7EjectAction: String, Codable, Equatable {
    case safeEject = "safe_eject"
}

enum T7EjectReason: String, Codable, Equatable {
    case diskBusy = "disk_busy"
    case diskArbitrationDissented = "disk_arbitration_dissented"
    case idleNotConnected = "idle_not_connected"
    case idleAlreadyUnmounted = "idle_already_unmounted"
    case timeMachineStillRunning = "time_machine_still_running"
    case unsafeTargetMultipleDisks = "unsafe_target_multiple_disks"
    case unsafeTargetInternalDisk = "unsafe_target_internal_disk"
    case unmountSucceededEjectFailed = "unmount_succeeded_eject_failed"
    case unexpectedError = "unexpected_error"
}

struct T7EjectResult: Codable, Equatable {
    let status: T7EjectStatus
    let reason: T7EjectReason?
    let action: T7EjectAction
    let wholeDisk: String?
    let apfsContainer: String?
    let volumes: [String]
    let timeMachineWasRunning: Bool
    let timeMachineStopped: Bool
    let remainingMountedVolumes: [String]
    let dissenterStatus: Int?
    let dissenterMessage: String?
    let startedAt: Date
    let endedAt: Date
    let message: String

    init(
        status: T7EjectStatus,
        reason: T7EjectReason?,
        action: T7EjectAction,
        wholeDisk: String?,
        apfsContainer: String?,
        volumes: [String],
        timeMachineWasRunning: Bool,
        timeMachineStopped: Bool,
        remainingMountedVolumes: [String],
        dissenterStatus: Int?,
        dissenterMessage: String?,
        startedAt: Date,
        endedAt: Date,
        message: String
    ) {
        self.status = status
        self.reason = reason
        self.action = action
        self.wholeDisk = wholeDisk
        self.apfsContainer = apfsContainer
        self.volumes = volumes
        self.timeMachineWasRunning = timeMachineWasRunning
        self.timeMachineStopped = timeMachineStopped
        self.remainingMountedVolumes = remainingMountedVolumes
        self.dissenterStatus = dissenterStatus
        self.dissenterMessage = dissenterMessage
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.message = message
    }

    static func message(for status: T7EjectStatus, reason: T7EjectReason?) -> String {
        switch status {
        case .success:
            return "T7 已安全推出。"
        case .idle:
            switch reason {
            case .idleAlreadyUnmounted:
                return "T7 已经处于未挂载状态。"
            case .idleNotConnected:
                return "未发现已连接的 T7。"
            default:
                return "T7 当前无需推出。"
            }
        case .failed:
            switch reason {
            case .diskBusy:
                return "T7 正在被占用，未强制推出。"
            case .diskArbitrationDissented:
                return "macOS 拒绝推出 T7，未强制推出。"
            case .timeMachineStillRunning:
                return "Time Machine 仍在运行，未推出 T7。"
            case .unsafeTargetMultipleDisks:
                return "T7 目标解析到多个磁盘，已停止。"
            case .unsafeTargetInternalDisk:
                return "目标看起来是内部磁盘，已停止。"
            case .unmountSucceededEjectFailed:
                return "T7 已卸载但推出失败。"
            case .unexpectedError:
                return "T7 推出时遇到未知错误。"
            default:
                return "T7 未能安全推出。"
            }
        }
    }

    static func idleNotConnected(startedAt: Date = Date(), endedAt: Date = Date()) -> T7EjectResult {
        T7EjectResult(
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
            startedAt: startedAt,
            endedAt: endedAt,
            message: message(for: .idle, reason: .idleNotConnected)
        )
    }

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    func stdoutJSONString() throws -> String {
        let data = try Self.encoder().encode(self)
        guard let json = String(data: data, encoding: .utf8) else {
            throw EncodingError.invalidValue(
                self,
                EncodingError.Context(
                    codingPath: [],
                    debugDescription: "Encoded T7 eject result was not valid UTF-8."
                )
            )
        }
        return json
    }

    private enum CodingKeys: String, CodingKey {
        case status
        case reason
        case action
        case wholeDisk
        case apfsContainer
        case volumes
        case timeMachineWasRunning
        case timeMachineStopped
        case remainingMountedVolumes
        case dissenterStatus
        case dissenterMessage
        case startedAt
        case endedAt
        case message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(T7EjectStatus.self, forKey: .status)
        reason = try container.decodeIfPresent(T7EjectReason.self, forKey: .reason)
        action = try container.decode(T7EjectAction.self, forKey: .action)
        wholeDisk = try container.decodeIfPresent(String.self, forKey: .wholeDisk)
        apfsContainer = try container.decodeIfPresent(String.self, forKey: .apfsContainer)
        volumes = try container.decode([String].self, forKey: .volumes)
        timeMachineWasRunning = try container.decode(Bool.self, forKey: .timeMachineWasRunning)
        timeMachineStopped = try container.decode(Bool.self, forKey: .timeMachineStopped)
        remainingMountedVolumes = try container.decode([String].self, forKey: .remainingMountedVolumes)
        dissenterStatus = try container.decodeIfPresent(Int.self, forKey: .dissenterStatus)
        dissenterMessage = try container.decodeIfPresent(String.self, forKey: .dissenterMessage)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        endedAt = try container.decode(Date.self, forKey: .endedAt)
        message = try container.decode(String.self, forKey: .message)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(status, forKey: .status)
        try container.encode(action, forKey: .action)
        try container.encode(volumes, forKey: .volumes)
        try container.encode(timeMachineWasRunning, forKey: .timeMachineWasRunning)
        try container.encode(timeMachineStopped, forKey: .timeMachineStopped)
        try container.encode(remainingMountedVolumes, forKey: .remainingMountedVolumes)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(endedAt, forKey: .endedAt)
        try container.encode(message, forKey: .message)

        try Self.encodeOptional(reason, forKey: .reason, into: &container)
        try Self.encodeOptional(wholeDisk, forKey: .wholeDisk, into: &container)
        try Self.encodeOptional(apfsContainer, forKey: .apfsContainer, into: &container)
        try Self.encodeOptional(dissenterStatus, forKey: .dissenterStatus, into: &container)
        try Self.encodeOptional(dissenterMessage, forKey: .dissenterMessage, into: &container)
    }

    private static func encodeOptional<T: Encodable>(
        _ value: T?,
        forKey key: CodingKeys,
        into container: inout KeyedEncodingContainer<CodingKeys>
    ) throws {
        if let value {
            try container.encode(value, forKey: key)
        } else {
            try container.encodeNil(forKey: key)
        }
    }
}
