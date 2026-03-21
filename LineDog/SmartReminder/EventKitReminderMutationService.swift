import EventKit
import Foundation

enum SmartReminderWriteError: Error {
    case calendarNotWritable
    case calendarNotFound
    case reminderNotFound
}

/// EventKit 创建/删除提醒；与 `EventKitRemindersBacking` 共用 `LineDogReminderEventStore.shared`。
final class EventKitReminderMutationService: ReminderMutationServing {
    private let store = LineDogReminderEventStore.shared

    func fetchReminderCalendarsForMutation() async throws -> [(String, String, Bool)] {
        // macOS 上在非主线程访问 `EKEventStore` 常得到空列表，导致「无可用列表」。
        await MainActor.run {
            store.calendars(for: .reminder).map {
                ($0.calendarIdentifier, $0.title, $0.allowsContentModifications)
            }
        }
    }

    func defaultCalendarForNewRemindersIdentifier() async throws -> String? {
        await MainActor.run {
            let all = store.calendars(for: .reminder)
            if let d = store.defaultCalendarForNewReminders(), d.allowsContentModifications {
                return d.calendarIdentifier
            }
            if let w = all.first(where: { $0.allowsContentModifications }) {
                return w.calendarIdentifier
            }
            return store.defaultCalendarForNewReminders()?.calendarIdentifier
                ?? all.first?.calendarIdentifier
        }
    }

    func createReminder(
        title: String,
        notes: String?,
        calendarIdentifier: String,
        dueDate: Date?,
        alarmAt: Date?,
        priority: Int
    ) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            DispatchQueue.main.async {
                do {
                    guard let cal = self.store.calendar(withIdentifier: calendarIdentifier) else {
                        throw SmartReminderWriteError.calendarNotFound
                    }
                    guard cal.allowsContentModifications else {
                        throw SmartReminderWriteError.calendarNotWritable
                    }
                    let rem = EKReminder(eventStore: self.store)
                    rem.title = title
                    rem.notes = notes
                    rem.calendar = cal
                    rem.priority = priority
                    let due = dueDate ?? alarmAt
                    if let due {
                        var dc = Calendar.current.dateComponents(
                            [.year, .month, .day, .hour, .minute],
                            from: due
                        )
                        dc.timeZone = Calendar.current.timeZone
                        rem.dueDateComponents = dc
                    }
                    if let alarmAt {
                        rem.addAlarm(EKAlarm(absoluteDate: alarmAt))
                    }
                    try self.store.save(rem, commit: true)
                    cont.resume(returning: rem.calendarItemIdentifier)
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    func removeReminder(calendarItemIdentifier: String) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            DispatchQueue.main.async {
                do {
                    guard let raw = self.store.calendarItem(withIdentifier: calendarItemIdentifier),
                          let rem = raw as? EKReminder
                    else {
                        throw SmartReminderWriteError.reminderNotFound
                    }
                    try self.store.remove(rem, commit: true)
                    cont.resume()
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }
}
