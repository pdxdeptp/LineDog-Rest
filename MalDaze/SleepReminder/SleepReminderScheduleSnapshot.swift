import Foundation

struct SleepReminderPlannedEventDisplay: Identifiable, Equatable {
    let id: String
    let kind: SleepReminderKind
    let title: String
    let fireDate: Date
    let isNext: Bool
}

/// Dashboard 展示的睡眠调度快照。
struct SleepReminderScheduleSnapshot: Equatable {
    /// 桌宠最近一次从磁盘读取 JSON 的时刻。
    let lastReadAt: Date
    /// Hermes 契约里的 `updatedAt`（读取失败时为 nil）。
    let contractUpdatedAt: String?
    let targetBedtime: SleepClockTime?
    let lockBedtime: SleepClockTime?
    let dayType: SleepDayType?
    let plannedEvents: [SleepReminderPlannedEventDisplay]

    var targetBedtimeLabel: String? {
        targetBedtime.map(Self.hhmmLabel)
    }

    var lockBedtimeLabel: String? {
        lockBedtime.map(Self.hhmmLabel)
    }

    var dayTypeLabel: String? {
        dayType.map { $0 == .training ? "训练日" : "休息日" }
    }

    static func hhmmLabel(_ clock: SleepClockTime) -> String {
        String(format: "%02d:%02d", clock.hour, clock.minute)
    }
}

extension SleepReminderKind {
    var scheduleTitle: String {
        switch self {
        case .shower: return "洗澡提醒（T-90）"
        case .wrapUp: return "收尾提醒（T-60）"
        case .washUp: return "洗漱提醒（T-30）"
        case .deadlineBell: return "睡觉 deadline"
        case .lockScreen: return "霸屏 lock"
        }
    }
}

enum SleepReminderScheduleSnapshotBuilder {
    static func make(
        contract: SleepScheduleContract,
        items: [SleepReminderScheduledItem],
        lastReadAt: Date
    ) -> SleepReminderScheduleSnapshot {
        let nextID = SleepReminderReconciler.nextActionableIndex(in: items).map { items[$0].stableID }
        let planned = items
            .filter { $0.state == .pending || $0.state == .catchUpNow }
            .map { item in
                SleepReminderPlannedEventDisplay(
                    id: item.stableID,
                    kind: item.event.kind,
                    title: item.event.kind.scheduleTitle,
                    fireDate: item.event.fireDate,
                    isNext: item.stableID == nextID
                )
            }
        return SleepReminderScheduleSnapshot(
            lastReadAt: lastReadAt,
            contractUpdatedAt: contract.updatedAt,
            targetBedtime: contract.targetBedtime,
            lockBedtime: contract.lockBedtime,
            dayType: contract.dayType,
            plannedEvents: planned
        )
    }

    static func failedRead(at lastReadAt: Date) -> SleepReminderScheduleSnapshot {
        SleepReminderScheduleSnapshot(
            lastReadAt: lastReadAt,
            contractUpdatedAt: nil,
            targetBedtime: nil,
            lockBedtime: nil,
            dayType: nil,
            plannedEvents: []
        )
    }
}

enum SleepScheduleTimestampFormatting {
    static func formatMalDazeReadTime(_ date: Date) -> String {
        makeDisplayFormatter().string(from: date)
    }

    static func formatHermesUpdatedAt(_ raw: String) -> String {
        if let parsed = parseISO8601(raw) {
            return makeDisplayFormatter().string(from: parsed)
        }
        return raw
    }

    private static func makeDisplayFormatter() -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }

    private static func parseISO8601(_ raw: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fractional.date(from: raw) { return d }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: raw)
    }

    static func formatEventFireDate(_ date: Date, calendar: Calendar = .current) -> String {
        let time = DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
        if calendar.isDateInToday(date) {
            return "今天 \(time)"
        }
        if calendar.isDateInTomorrow(date) {
            return "明天 \(time)"
        }
        let day = DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none)
        return "\(day) \(time)"
    }
}
