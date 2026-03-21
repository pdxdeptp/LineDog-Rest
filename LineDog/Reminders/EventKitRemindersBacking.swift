import EventKit
import Foundation

enum RemindersEventKitError: Error {
    case reminderNotFound
}

/// 生产环境 EventKit 实现：谓词在系统侧过滤「今日未完成」；监听 `.EKEventStoreChanged` 仅回调、不隐式写入。
final class EventKitRemindersBacking: NSObject, RemindersEventStoreBacking {
    private let store = EKEventStore()
    private let onExternalChange: @Sendable () -> Void

    init(onExternalChange: @escaping @Sendable () -> Void) {
        self.onExternalChange = onExternalChange
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeChanged),
            name: .EKEventStoreChanged,
            object: store
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func storeChanged() {
        onExternalChange()
    }

    func requestAccess() async throws -> Bool {
        try await withCheckedThrowingContinuation { cont in
            store.requestAccess(to: .reminder) { granted, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                cont.resume(returning: granted)
            }
        }
    }

    func fetchReminderCalendars() async throws -> [RemindersCalendarDescriptor] {
        store.calendars(for: .reminder).map {
            RemindersCalendarDescriptor(calendarIdentifier: $0.calendarIdentifier, title: $0.title)
        }
    }

    func fetchIncompleteRemindersForToday(calendarId: String) async throws -> [ReminderDisplayItem] {
        guard let cal = store.calendar(withIdentifier: calendarId) else { return [] }
        let calWrap = Calendar.current
        let start = calWrap.startOfDay(for: Date())
        guard let end = calWrap.date(byAdding: .day, value: 1, to: start) else { return [] }
        let pred = store.predicateForIncompleteReminders(
            withDueDateStarting: start,
            ending: end,
            calendars: [cal]
        )
        return try await withCheckedThrowingContinuation { cont in
            store.fetchReminders(matching: pred) { list in
                let items = (list ?? []).map {
                    ReminderDisplayItem(
                        calendarItemIdentifier: $0.calendarItemIdentifier,
                        title: $0.title ?? ""
                    )
                }
                cont.resume(returning: items)
            }
        }
    }

    func completeReminder(calendarItemIdentifier: String) async throws {
        guard let raw = store.calendarItem(withIdentifier: calendarItemIdentifier),
              let reminder = raw as? EKReminder
        else {
            throw RemindersEventKitError.reminderNotFound
        }
        reminder.isCompleted = true
        reminder.completionDate = Date()
        try store.save(reminder, commit: true)
    }
}
