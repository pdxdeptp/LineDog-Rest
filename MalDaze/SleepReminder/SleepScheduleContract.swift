import Foundation

enum SleepDayType: String, Equatable {
    case training
    case rest
}

struct SleepClockTime: Equatable {
    let hour: Int
    let minute: Int

    init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    init?(hhmm: String) {
        let parts = hhmm.split(separator: ":")
        guard parts.count == 2,
              let h = Int(parts[0]),
              let m = Int(parts[1]),
              (0...23).contains(h),
              (0...59).contains(m)
        else { return nil }
        hour = h
        minute = m
    }
}

struct SleepScheduleContract: Equatable {
    let schemaVersion: Int
    let targetBedtime: SleepClockTime
    let lockBedtime: SleepClockTime
    let dayType: SleepDayType
    let updatedAt: String
}

enum SleepScheduleContractError: Error, Equatable {
    case fileNotFound
    case readFailed
    case invalidJSON
    case missingField(String)
    case invalidDayType(String)
    case invalidClockTime(String)
}

struct SleepScheduleContractReader {
    let fileURL: URL

    static var defaultHermesFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".hermes/data/sleep/sleep_schedule.json")
    }

    init(fileURL: URL = SleepScheduleContractReader.defaultHermesFileURL) {
        self.fileURL = fileURL
    }

    func read() throws -> SleepScheduleContract {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw SleepScheduleContractError.fileNotFound
        }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw SleepScheduleContractError.readFailed
        }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SleepScheduleContractError.invalidJSON
        }

        guard let schemaVersion = root["schemaVersion"] as? Int else {
            throw SleepScheduleContractError.missingField("schemaVersion")
        }
        guard let targetRaw = root["targetBedtime"] as? String,
              let target = SleepClockTime(hhmm: targetRaw)
        else {
            throw SleepScheduleContractError.missingField("targetBedtime")
        }
        guard let lockRaw = root["lockBedtime"] as? String,
              let lock = SleepClockTime(hhmm: lockRaw)
        else {
            throw SleepScheduleContractError.missingField("lockBedtime")
        }
        guard let dayTypeRaw = root["dayType"] as? String else {
            throw SleepScheduleContractError.missingField("dayType")
        }
        guard let dayType = SleepDayType(rawValue: dayTypeRaw) else {
            throw SleepScheduleContractError.invalidDayType(dayTypeRaw)
        }
        guard let updatedAt = root["updatedAt"] as? String, !updatedAt.isEmpty else {
            throw SleepScheduleContractError.missingField("updatedAt")
        }

        return SleepScheduleContract(
            schemaVersion: schemaVersion,
            targetBedtime: target,
            lockBedtime: lock,
            dayType: dayType,
            updatedAt: updatedAt
        )
    }

    static func userFacingMessage(for error: SleepScheduleContractError) -> String {
        switch error {
        case .fileNotFound:
            return "未找到 Hermes 睡眠配置，请确认晨报已运行。"
        case .readFailed:
            return "无法读取 sleep_schedule.json。"
        case .invalidJSON:
            return "sleep_schedule.json 格式无效。"
        case .missingField(let field):
            return "睡眠配置缺少字段：\(field)。"
        case .invalidDayType(let raw):
            return "dayType 无效：\(raw)。"
        case .invalidClockTime(let raw):
            return "时间格式无效：\(raw)。"
        }
    }
}
