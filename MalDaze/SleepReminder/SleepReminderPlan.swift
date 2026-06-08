import Foundation

enum SleepReminderKind: Equatable {
    case shower
    case wrapUp
    case washUp
    case deadlineBell
    case lockScreen
}

struct SleepReminderEvent: Equatable {
    let fireDate: Date
    let kind: SleepReminderKind
    let message: String
}

struct SleepReminderUserSettings: Equatable {
    var remindersEnabled: Bool
    var lockScreenEnabled: Bool
    var showerReminderEnabled: Bool
}

enum SleepScheduleAnchorBuilder {
    /// 下一次触发时刻：若当日该时刻已过，则取次日（适用于 00:00 等凌晨目标）。
    static func nextOccurrence(of clock: SleepClockTime, from now: Date, calendar: Calendar) -> Date? {
        var dayComps = calendar.dateComponents([.year, .month, .day], from: now)
        dayComps.hour = clock.hour
        dayComps.minute = clock.minute
        dayComps.second = 0
        guard var candidate = calendar.date(from: dayComps) else { return nil }
        if candidate <= now {
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: candidate) else { return nil }
            candidate = nextDay
        }
        return candidate
    }
}

enum SleepReminderPlanBuilder {
    static func events(
        contract: SleepScheduleContract,
        settings: SleepReminderUserSettings,
        now: Date,
        calendar: Calendar = .current
    ) -> [SleepReminderEvent] {
        guard settings.remindersEnabled || settings.lockScreenEnabled else { return [] }

        guard let targetDate = SleepScheduleAnchorBuilder.nextOccurrence(
            of: contract.targetBedtime,
            from: now,
            calendar: calendar
        ) else { return [] }

        let lockDate = SleepScheduleAnchorBuilder.nextOccurrence(
            of: contract.lockBedtime,
            from: now,
            calendar: calendar
        )

        var planned: [SleepReminderEvent] = []

        if settings.remindersEnabled {
            if settings.showerReminderEnabled, contract.dayType == .training {
                if let d = calendar.date(byAdding: .minute, value: -90, to: targetDate),
                   SleepReminderPlanBuilder.isStillSchedulable(fireDate: d, now: now) {
                    planned.append(SleepReminderEvent(
                        fireDate: d,
                        kind: .shower,
                        message: "该洗澡了，睡前 1.5h 洗才不会热得睡不着"
                    ))
                }
            }
            if let d = calendar.date(byAdding: .minute, value: -60, to: targetDate),
               SleepReminderPlanBuilder.isStillSchedulable(fireDate: d, now: now) {
                planned.append(SleepReminderEvent(
                    fireDate: d,
                    kind: .wrapUp,
                    message: "今天差不多了，别开新活了，准备收尾"
                ))
            }
            if let d = calendar.date(byAdding: .minute, value: -30, to: targetDate),
               SleepReminderPlanBuilder.isStillSchedulable(fireDate: d, now: now) {
                planned.append(SleepReminderEvent(
                    fireDate: d,
                    kind: .washUp,
                    message: "该去洗漱了，真的要睡了"
                ))
            }
            if SleepReminderPlanBuilder.isStillSchedulable(fireDate: targetDate, now: now) {
                planned.append(SleepReminderEvent(
                    fireDate: targetDate,
                    kind: .deadlineBell,
                    message: "要睡觉了"
                ))
            }
        }

        if settings.lockScreenEnabled,
           let lockDate,
           SleepReminderPlanBuilder.isStillSchedulable(fireDate: lockDate, now: now) {
            planned.append(SleepReminderEvent(
                fireDate: lockDate,
                kind: .lockScreen,
                message: "已经过点了，睡觉"
            ))
        }

        return planned.sorted { $0.fireDate < $1.fireDate }
    }

    /// 距 `fireDate` 已过不超过 `grace` 秒时仍视为可触发（避免整点重读 JSON 把当分钟提醒跳过）。
    static func isStillSchedulable(fireDate: Date, now: Date, grace: TimeInterval = 90) -> Bool {
        fireDate.timeIntervalSince(now) > -grace
    }
}
