import Foundation

struct TodayTodoEntry: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var dateISO: String
    var rolledFromDateISO: String?
    var isCompleted: Bool
    let createdAt: Date
    var completedAt: Date?
    var sortIndex: Int
    var deletedAt: Date?

    init(
        id: UUID,
        title: String,
        dateISO: String,
        rolledFromDateISO: String?,
        isCompleted: Bool,
        createdAt: Date,
        completedAt: Date?,
        sortIndex: Int,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.dateISO = dateISO
        self.rolledFromDateISO = rolledFromDateISO
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.sortIndex = sortIndex
        self.deletedAt = deletedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        dateISO = try container.decode(String.self, forKey: .dateISO)
        rolledFromDateISO = try container.decodeIfPresent(String.self, forKey: .rolledFromDateISO)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        sortIndex = try container.decode(Int.self, forKey: .sortIndex)
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
    }
}

struct TodayTodoFile: Codable, Equatable {
    var version: Int
    var entries: [TodayTodoEntry]
}

enum TodayTodoStoreError: Error, Equatable {
    case unsupportedVersion(Int)
    case decodeFailed
    case writeFailed
}

enum TodayTodoFormatting {
    static func isoDate(_ date: Date) -> String {
        let cal = Calendar.current
        let y = cal.component(.year, from: date)
        let m = cal.component(.month, from: date)
        let d = cal.component(.day, from: date)
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    static func isoDate(byAddingDays days: Int, to iso: String) -> String? {
        guard let base = parseISODate(iso) else { return nil }
        guard let shifted = Calendar.current.date(byAdding: .day, value: days, to: base) else { return nil }
        return Self.isoDate(shifted)
    }

    static func parseISODate(_ iso: String) -> Date? {
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var comps = DateComponents()
        comps.year = parts[0]
        comps.month = parts[1]
        comps.day = parts[2]
        return Calendar.current.date(from: comps)
    }

    static func rolledFromHint(_ rolledFromDateISO: String?) -> String? {
        guard let rolledFromDateISO, let date = parseISODate(rolledFromDateISO) else { return nil }
        let cal = Calendar.current
        let m = cal.component(.month, from: date)
        let d = cal.component(.day, from: date)
        return "自 \(m)/\(d) 顺延"
    }

    static func historySectionTitle(_ dateISO: String) -> String {
        guard let date = parseISODate(dateISO) else { return dateISO }
        let cal = Calendar.current
        let m = cal.component(.month, from: date)
        let d = cal.component(.day, from: date)
        let weekday = cal.component(.weekday, from: date)
        let weekdayNames = ["", "周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        let weekdayLabel = weekdayNames.indices.contains(weekday) ? weekdayNames[weekday] : ""
        return "\(m)月\(d)日 \(weekdayLabel)"
    }

    static func deletedAtHint(_ deletedAt: Date) -> String {
        let cal = Calendar.current
        let m = cal.component(.month, from: deletedAt)
        let d = cal.component(.day, from: deletedAt)
        let hour = cal.component(.hour, from: deletedAt)
        let minute = cal.component(.minute, from: deletedAt)
        return String(format: "删除于 %d/%d %02d:%02d", m, d, hour, minute)
    }
}

struct TodayTodoHistorySection: Identifiable, Equatable {
    let dateISO: String
    let entries: [TodayTodoEntry]

    var id: String { dateISO }
}
