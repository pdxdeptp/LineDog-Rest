import EventKit
import Foundation

enum SmartReminderWriteError: Error {
    case calendarNotWritable
    case calendarNotFound
    case reminderNotFound
}

/// EventKit 创建/删除提醒；独立 `EKEventStore`（与列表拉取实例分离，共享系统已授权限）。
final class EventKitReminderMutationService: ReminderMutationServing {
    private let store = EKEventStore()

    func fetchReminderCalendarsForMutation() async throws -> [(String, String, Bool)] {
        store.calendars(for: .reminder).map {
            ($0.calendarIdentifier, $0.title, $0.allowsContentModifications)
        }
    }

    func defaultCalendarForNewRemindersIdentifier() async throws -> String? {
        store.defaultCalendarForNewReminders()?.calendarIdentifier
    }

    func createReminder(
        title: String,
        notes: String?,
        calendarIdentifier: String,
        alarmDate: Date?,
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
                    if let alarmDate {
                        var dc = Calendar.current.dateComponents(
                            [.year, .month, .day, .hour, .minute],
                            from: alarmDate
                        )
                        dc.timeZone = Calendar.current.timeZone
                        rem.dueDateComponents = dc
                        rem.addAlarm(EKAlarm(absoluteDate: alarmDate))
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
