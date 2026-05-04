import Foundation

/// 按「计划」视图分组后的区块，供 SwiftUI `ForEach`。
struct DeskReminderDaySection: Identifiable, Equatable {
    /// 有截止日的为当日 0 点；无截止日为 `nil`（单独一节）。
    let dayStart: Date?
    let headerTitle: String
    let items: [ReminderDisplayItem]

    var id: String {
        if let d = dayStart {
            return "d-\(d.timeIntervalSince1970)"
        }
        return "no-date"
    }
}

/// 将合并后的列表按本地日历日分组，并生成与系统「计划」类似的节标题。
enum DeskReminderDayGroups {
    static func sections(
        items: [ReminderDisplayItem],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [DeskReminderDaySection] {
        var byDay: [Date: [ReminderDisplayItem]] = [:]
        var noDue: [ReminderDisplayItem] = []
        for item in items {
            guard let due = item.dueDate else {
                noDue.append(item)
                continue
            }
            let start = calendar.startOfDay(for: due)
            byDay[start, default: []].append(item)
        }

        let sortInDay: (ReminderDisplayItem, ReminderDisplayItem) -> Bool = { a, b in
            switch (a.dueDate, b.dueDate) {
            case let (x?, y?): return x < y
            case (_?, nil): return true
            case (nil, _?): return false
            default: return a.title.localizedStandardCompare(b.title) == .orderedAscending
            }
        }

        let keys = byDay.keys.sorted()
        var out: [DeskReminderDaySection] = keys.map { day in
            let sortedItems = (byDay[day] ?? []).sorted(by: sortInDay)
            let title = DeskReminderSectionHeaderFormatter.title(forDayStart: day, now: now, calendar: calendar)
            return DeskReminderDaySection(dayStart: day, headerTitle: title, items: sortedItems)
        }

        if !noDue.isEmpty {
            let sorted = noDue.sorted { a, b in
                a.title.localizedStandardCompare(b.title) == .orderedAscending
            }
            out.append(DeskReminderDaySection(dayStart: nil, headerTitle: "无日期", items: sorted))
        }
        return out
    }
}

enum DeskReminderSectionHeaderFormatter {
    static func title(forDayStart dayStart: Date, now: Date, calendar: Calendar) -> String {
        let loc = Locale(identifier: "zh_CN")
        let today = calendar.startOfDay(for: now)

        if calendar.isDate(dayStart, inSameDayAs: today) {
            return "今天 \(weekdayAndMonthDay(dayStart, calendar: calendar, locale: loc))"
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
           calendar.isDate(dayStart, inSameDayAs: tomorrow) {
            return "明天 \(weekdayAndMonthDay(dayStart, calendar: calendar, locale: loc))"
        }
        if let plus2 = calendar.date(byAdding: .day, value: 2, to: today),
           calendar.isDate(dayStart, inSameDayAs: plus2) {
            return "后天 \(weekdayAndMonthDay(dayStart, calendar: calendar, locale: loc))"
        }
        return monthDayAndWeekday(dayStart, calendar: calendar, locale: loc)
    }

    /// 例：`周五 3月21日`
    private static func weekdayAndMonthDay(_ date: Date, calendar: Calendar, locale: Locale) -> String {
        let w = DateFormatter()
        w.locale = locale
        w.timeZone = calendar.timeZone
        w.dateFormat = "EEE"
        let m = DateFormatter()
        m.locale = locale
        m.timeZone = calendar.timeZone
        m.dateFormat = "M月d日"
        return "\(w.string(from: date)) \(m.string(from: date))"
    }

    /// 例：`3月24日 周二`
    private static func monthDayAndWeekday(_ date: Date, calendar: Calendar, locale: Locale) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = calendar.timeZone
        f.dateFormat = "M月d日 EEE"
        return f.string(from: date)
    }
}

/// 桌宠列表合并：日常（今日）与非日常（7 日内）去重后按 due 排序。
enum DeskReminderSidebarMerger {
    static func mergedDisplayItems(
        routineToday: [ReminderDisplayItem],
        nonRoutineWeek: [ReminderDisplayItem]
    ) -> [ReminderDisplayItem] {
        var seen = Set<String>()
        var combined: [ReminderDisplayItem] = []
        for item in routineToday + nonRoutineWeek {
            if seen.insert(item.id).inserted {
                combined.append(item)
            }
        }
        return combined.sorted { a, b in
            switch (a.dueDate, b.dueDate) {
            case let (x?, y?):
                return x < y
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return a.title.localizedStandardCompare(b.title) == .orderedAscending
            }
        }
    }
}

/// 列表卡片时间列：当天仅时刻；明天带前缀；同周 `EEE HH:mm`；否则短日期。
enum DeskReminderTimeFormatter {
    /// 「计划」行内：有具体时刻显示 `HH:mm`；仅日期型显示「全天」；无截止为「—」。
    static func timeOnly(dueDate: Date?, hasExplicitTime: Bool = true, calendar: Calendar = .current) -> String {
        guard let dueDate else { return "—" }
        guard hasExplicitTime else { return "全天" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.timeZone = calendar.timeZone
        f.dateFormat = "HH:mm"
        return f.string(from: dueDate)
    }

    static func displayString(dueDate: Date?, now: Date = Date(), calendar: Calendar = .current) -> String {
        guard let dueDate else { return "—" }
        let loc = Locale(identifier: "zh_CN")
        let todayStart = calendar.startOfDay(for: now)
        if calendar.isDate(dueDate, inSameDayAs: todayStart) {
            let f = DateFormatter()
            f.locale = loc
            f.timeZone = calendar.timeZone
            f.dateFormat = "HH:mm"
            return f.string(from: dueDate)
        }
        if let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart),
           calendar.isDate(dueDate, inSameDayAs: tomorrowStart) {
            let f = DateFormatter()
            f.locale = loc
            f.timeZone = calendar.timeZone
            f.dateFormat = "HH:mm"
            return "明天 " + f.string(from: dueDate)
        }
        let w0 = calendar.component(.weekOfYear, from: now)
        let y0 = calendar.component(.yearForWeekOfYear, from: now)
        let w1 = calendar.component(.weekOfYear, from: dueDate)
        let y1 = calendar.component(.yearForWeekOfYear, from: dueDate)
        if w0 == w1 && y0 == y1 {
            let f = DateFormatter()
            f.locale = loc
            f.timeZone = calendar.timeZone
            f.dateFormat = "EEE HH:mm"
            return f.string(from: dueDate)
        }
        let f = DateFormatter()
        f.locale = loc
        f.timeZone = calendar.timeZone
        f.dateFormat = "M月d日 HH:mm"
        return f.string(from: dueDate)
    }
}
