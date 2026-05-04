import Foundation

/// LLM 输出 JSON 契约；扁平整型日期字段，避免 ISO8601 解析歧义。
struct LLMReminderJSONPayload: Codable, Equatable {
    let title: String
    /// PRD：日常 / 非日常分类；缺省按 `false`。
    let is_routine: Bool
    let notes: String?
    let target_list_name: String
    let has_alarm: Bool
    let alarm_date: AlarmDateFields?
    let priority: Int
    /// 可选重复规则；与 Apple 提醒事项「重复」一致，由客户端写入 `EKRecurrenceRule`。
    let recurrence: RecurrenceFields?

    struct RecurrenceFields: Codable, Equatable {
        let frequency: String?
        let interval: Int?
        let days_of_week: [Int]?
        let day_of_month: Int?

        enum CodingKeys: String, CodingKey {
            case frequency
            case interval
            case days_of_week
            case daysOfWeek
            case day_of_month
            case dayOfMonth
        }

        init(
            frequency: String?,
            interval: Int?,
            days_of_week: [Int]?,
            day_of_month: Int?
        ) {
            self.frequency = frequency
            self.interval = interval
            self.days_of_week = days_of_week
            self.day_of_month = day_of_month
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            frequency = try c.decodeIfPresent(String.self, forKey: .frequency)
            interval = try c.decodeIfPresent(Int.self, forKey: .interval)
            if let a = try c.decodeIfPresent([Int].self, forKey: .days_of_week) {
                days_of_week = a
            } else {
                days_of_week = try c.decodeIfPresent([Int].self, forKey: .daysOfWeek)
            }
            if let d = try c.decodeIfPresent(Int.self, forKey: .day_of_month) {
                day_of_month = d
            } else {
                day_of_month = try c.decodeIfPresent(Int.self, forKey: .dayOfMonth)
            }
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encodeIfPresent(frequency, forKey: .frequency)
            try c.encodeIfPresent(interval, forKey: .interval)
            try c.encodeIfPresent(days_of_week, forKey: .days_of_week)
            try c.encodeIfPresent(day_of_month, forKey: .day_of_month)
        }
    }

    struct AlarmDateFields: Codable, Equatable {
        let year: Int
        let month: Int
        let day: Int
        let hour: Int
        let minute: Int
        /// JSON 中 `hour`/`minute` 均为 null 时为 true；客户端会按任务内容推断真实时刻。
        let isTimeUnspecified: Bool

        enum CodingKeys: String, CodingKey {
            case year, month, day, hour, minute
        }

        init(year: Int, month: Int, day: Int, hour: Int, minute: Int, isTimeUnspecified: Bool = false) {
            self.year = year
            self.month = month
            self.day = day
            self.hour = hour
            self.minute = minute
            self.isTimeUnspecified = isTimeUnspecified
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            year = try c.decode(Int.self, forKey: .year)
            month = try c.decode(Int.self, forKey: .month)
            day = try c.decode(Int.self, forKey: .day)
            let h = try c.decodeIfPresent(Int.self, forKey: .hour)
            let m = try c.decodeIfPresent(Int.self, forKey: .minute)
            if h == nil && m == nil {
                // 占位；`isTimeUnspecified` 触发 `SmartReminderInferredTime` 覆盖
                hour = 12
                minute = 0
                isTimeUnspecified = true
            } else {
                hour = min(23, max(0, h ?? 0))
                minute = min(59, max(0, m ?? 0))
                isTimeUnspecified = false
            }
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(year, forKey: .year)
            try c.encode(month, forKey: .month)
            try c.encode(day, forKey: .day)
            try c.encode(hour, forKey: .hour)
            try c.encode(minute, forKey: .minute)
        }

        func withExplicitTime(hour: Int, minute: Int) -> AlarmDateFields {
            AlarmDateFields(
                year: year,
                month: month,
                day: day,
                hour: min(23, max(0, hour)),
                minute: min(59, max(0, minute)),
                isTimeUnspecified: false
            )
        }
    }

    enum CodingKeys: String, CodingKey {
        case title
        case is_routine
        case isRoutine
        case notes
        case target_list_name
        case targetListName
        case has_alarm
        case hasAlarm
        case alarm_date
        case alarmDate
        case priority
        case recurrence
    }

    init(
        title: String,
        is_routine: Bool,
        notes: String?,
        target_list_name: String,
        has_alarm: Bool,
        alarm_date: AlarmDateFields?,
        priority: Int,
        recurrence: RecurrenceFields? = nil
    ) {
        self.title = title
        self.is_routine = is_routine
        self.notes = notes
        self.target_list_name = target_list_name
        self.has_alarm = has_alarm
        self.alarm_date = alarm_date
        self.priority = priority
        self.recurrence = recurrence
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decode(String.self, forKey: .title)
        // Gemini 等模型常输出 camelCase，缺省会误判为 false。
        is_routine =
            try c.decodeIfPresent(Bool.self, forKey: .is_routine)
            ?? c.decodeIfPresent(Bool.self, forKey: .isRoutine)
            ?? false
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        if let s = try c.decodeIfPresent(String.self, forKey: .target_list_name) {
            target_list_name = s
        } else if let s = try c.decodeIfPresent(String.self, forKey: .targetListName) {
            target_list_name = s
        } else {
            target_list_name = "Reminders"
        }
        has_alarm =
            try c.decodeIfPresent(Bool.self, forKey: .has_alarm)
            ?? c.decodeIfPresent(Bool.self, forKey: .hasAlarm)
            ?? false
        // 模型常输出 ISO8601 字符串；若用 AlarmDateFields 强解会在类型不符时抛错导致整段解码失败。
        alarm_date = Self.decodeAlarmDateFlexible(from: c, keys: [.alarm_date, .alarmDate])
        priority = try c.decodeIfPresent(Int.self, forKey: .priority) ?? 0
        recurrence = try c.decodeIfPresent(RecurrenceFields.self, forKey: .recurrence)
    }

    /// 先尝试 `{year,month,...}`，再尝试 RFC3339/ISO8601 字符串（与当前系统时区的墙钟一致再写回整型字段）。
    private static func decodeAlarmDateFlexible(
        from c: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> AlarmDateFields? {
        for key in keys {
            guard c.contains(key) else { continue }
            if let obj = try? c.decode(AlarmDateFields.self, forKey: key) {
                return obj
            }
            if let str = try? c.decode(String.self, forKey: key),
               let fields = alarmFields(fromISO8601String: str) {
                return fields
            }
        }
        return nil
    }

    private static func alarmFields(fromISO8601String string: String) -> AlarmDateFields? {
        let s = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        let formatters: [ISO8601DateFormatter] = {
            let a = ISO8601DateFormatter()
            a.formatOptions = [.withInternetDateTime, .withTimeZone]
            let b = ISO8601DateFormatter()
            b.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone]
            return [a, b]
        }()
        guard let date = formatters.compactMap({ $0.date(from: s) }).first else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        let dc = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        guard let y = dc.year, let m = dc.month, let d = dc.day, let h = dc.hour, let min = dc.minute else {
            return nil
        }
        return AlarmDateFields(year: y, month: m, day: d, hour: h, minute: min, isTimeUnspecified: false)
    }

    /// 未指定时刻的 `alarm_date` 按标题/备注/原文推断墙钟后再参与 due/alarm 计算。
    func withInferredAlarmWallClock(rawUserInput: String) -> LLMReminderJSONPayload {
        guard let a = alarm_date, a.isTimeUnspecified else { return self }
        let inferred = SmartReminderInferredTime.inferHourMinute(
            title: title,
            notes: notes,
            rawUserInput: rawUserInput
        )
        let newA = a.withExplicitTime(hour: inferred.hour, minute: inferred.minute)
        return LLMReminderJSONPayload(
            title: title,
            is_routine: is_routine,
            notes: notes,
            target_list_name: target_list_name,
            has_alarm: has_alarm,
            alarm_date: newA,
            priority: priority,
            recurrence: recurrence
        )
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(title, forKey: .title)
        try c.encode(is_routine, forKey: .is_routine)
        try c.encodeIfPresent(notes, forKey: .notes)
        try c.encode(target_list_name, forKey: .target_list_name)
        try c.encode(has_alarm, forKey: .has_alarm)
        try c.encodeIfPresent(alarm_date, forKey: .alarm_date)
        try c.encode(priority, forKey: .priority)
        try c.encodeIfPresent(recurrence, forKey: .recurrence)
    }

    /// 由 `alarm_date` 字段得到时刻，不要求 `has_alarm`（用于日常默认带到时提醒等策略）。
    func dateFromAlarmFields(in timeZone: TimeZone, calendar: Calendar = .current) -> Date? {
        guard let a = alarm_date else { return nil }
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

    func alarmDate(in timeZone: TimeZone, calendar: Calendar = .current) -> Date? {
        guard has_alarm else { return nil }
        return dateFromAlarmFields(in: timeZone, calendar: calendar)
    }
}

enum LLMReminderJSONDecoderService {
    /// 支持根节点为**单个对象**或**对象数组**（模型常把多任务输出成 `[{...},{...}]`）。
    static func decodePayloads(from data: Data) throws -> [LLMReminderJSONPayload] {
        let dec = JSONDecoder()
        if let arr = try? dec.decode([LLMReminderJSONPayload].self, from: data) {
            return arr
        }
        return [try dec.decode(LLMReminderJSONPayload.self, from: data)]
    }

    static func decodePayloads(fromModelText text: String) throws -> [LLMReminderJSONPayload] {
        let trimmed = Self.stripMarkdownFence(text)
        guard let data = trimmed.data(using: .utf8) else {
            throw SmartReminderParseError.notUTF8
        }
        return try decodePayloads(from: data)
    }

    static func decode(from data: Data) throws -> LLMReminderJSONPayload {
        let list = try decodePayloads(from: data)
        guard list.count == 1, let one = list.first else {
            if list.isEmpty { throw SmartReminderParseError.emptyDecodedList }
            throw SmartReminderParseError.expectedSinglePayload
        }
        return one
    }

    /// 去掉 ```json 围栏等杂质后再解码（**恰好一个** JSON 对象）。
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

enum SmartReminderParseError: Error, Equatable {
    case notUTF8
    case emptyDecodedList
    case expectedSinglePayload
}
