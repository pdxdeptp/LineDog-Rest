import Foundation

/// LLM 输出 JSON 契约（PRD 4.2）；扁平整型日期字段，避免 ISO8601 解析歧义。
struct LLMReminderJSONPayload: Codable, Equatable {
    let title: String
    let notes: String?
    let target_list_name: String
    let has_alarm: Bool
    let alarm_date: AlarmDateFields?
    let priority: Int

    struct AlarmDateFields: Codable, Equatable {
        let year: Int
        let month: Int
        let day: Int
        let hour: Int
        let minute: Int
    }

    func alarmDate(in timeZone: TimeZone, calendar: Calendar = .current) -> Date? {
        guard has_alarm, let a = alarm_date else { return nil }
        var cal = calendar
        cal.timeZone = timeZone
        var dc = DateComponents()
        dc.year = a.year
        dc.month = a.month
        dc.day = a.day
        dc.hour = a.hour
        dc.minute = a.minute
        dc.second = 0
        return cal.date(from: dc)
    }
}

enum LLMReminderJSONDecoderService {
    static func decode(from data: Data) throws -> LLMReminderJSONPayload {
        let dec = JSONDecoder()
        return try dec.decode(LLMReminderJSONPayload.self, from: data)
    }

    /// 去掉 ```json 围栏等杂质后再解码。
    static func decode(fromModelText text: String) throws -> LLMReminderJSONPayload {
        let trimmed = Self.stripMarkdownFence(text)
        guard let data = trimmed.data(using: .utf8) else {
            throw SmartReminderParseError.notUTF8
        }
        return try decode(from: data)
    }

    static func stripMarkdownFence(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            s = String(s.drop(while: { $0 != "\n" }).dropFirst())
            if let end = s.range(of: "```", options: .backwards) {
                s = String(s[..<end.lowerBound])
            }
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum SmartReminderParseError: Error {
    case notUTF8
}
