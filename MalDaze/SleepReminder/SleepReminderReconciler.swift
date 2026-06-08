import Foundation

enum SleepReminderEventExecutionState: Equatable {
    case pending
    case catchUpNow
    case fired
    case skipped
}

struct SleepReminderScheduledItem: Equatable {
    let event: SleepReminderEvent
    let stableID: String
    let state: SleepReminderEventExecutionState
}

enum SleepReminderReconciler {
    static func stableEventID(contractUpdatedAt: String, event: SleepReminderEvent) -> String {
        "\(contractUpdatedAt)|\(event.kind)|\(Int(event.fireDate.timeIntervalSince1970))"
    }

    static func buildSchedule(
        contract: SleepScheduleContract,
        settings: SleepReminderUserSettings,
        now: Date,
        firedIDs: Set<String>,
        grace: TimeInterval = SleepReminderSchedulingPolicy.missedEventGrace,
        calendar: Calendar = .current
    ) -> [SleepReminderScheduledItem] {
        let events = SleepReminderPlanBuilder.events(
            contract: contract,
            settings: settings,
            now: now,
            calendar: calendar
        )
        return events.map { event in
            let stableID = stableEventID(contractUpdatedAt: contract.updatedAt, event: event)
            let state = executionState(
                fireDate: event.fireDate,
                stableID: stableID,
                now: now,
                firedIDs: firedIDs,
                grace: grace
            )
            return SleepReminderScheduledItem(event: event, stableID: stableID, state: state)
        }
    }

    static func executionState(
        fireDate: Date,
        stableID: String,
        now: Date,
        firedIDs: Set<String>,
        grace: TimeInterval
    ) -> SleepReminderEventExecutionState {
        if firedIDs.contains(stableID) {
            return .fired
        }
        let lateness = now.timeIntervalSince(fireDate)
        if lateness > grace {
            return .skipped
        }
        if lateness >= 0 {
            return .catchUpNow
        }
        return .pending
    }

    static func nextActionableIndex(in items: [SleepReminderScheduledItem]) -> Int? {
        items.firstIndex { $0.state == .pending || $0.state == .catchUpNow }
    }

    static func pendingTimerItems(in items: [SleepReminderScheduledItem]) -> [SleepReminderScheduledItem] {
        items.filter { $0.state == .pending }
    }

    static func catchUpItems(in items: [SleepReminderScheduledItem]) -> [SleepReminderScheduledItem] {
        items.filter { $0.state == .catchUpNow }
    }
}
