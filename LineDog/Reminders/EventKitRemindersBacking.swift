import EventKit
import Foundation

enum RemindersEventKitError: Error {
    case reminderNotFound
}

/// 进程内唯一提醒用 `EKEventStore`。macOS 上多个实例时，未走「连接」的那一个常枚举不出日历，导致智能写入误判「无列表」。
enum LineDogReminderEventStore {
    static let shared = EKEventStore()
}

/// 生产环境 EventKit 实现：监听 `.EKEventStoreChanged` 仅回调、不隐式写入。
final class EventKitRemindersBacking: NSObject, RemindersEventStoreBacking {
    private let store: EKEventStore
    private let onExternalChange: @Sendable () -> Void

    init(
        store: EKEventStore = LineDogReminderEventStore.shared,
        onExternalChange: @escaping @Sendable () -> Void
    ) {
        self.store = store
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
        if #available(macOS 14.0, *) {
            switch EKEventStore.authorizationStatus(for: .reminder) {
            case .fullAccess, .authorized:
                return true
            case .denied, .restricted:
                return false
            case .notDetermined, .writeOnly:
                break
            @unknown default:
                break
            }
        }
        return try await withCheckedThrowingContinuation { cont in
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

    func fetchDeskSidebarReminders(calendarId: String) async throws -> [ReminderDisplayItem] {
        guard let cal = store.calendar(withIdentifier: calendarId) else { return [] }
        let calWrap = Calendar.current
        let startToday = calWrap.startOfDay(for: Date())
        guard let endToday = calWrap.date(byAdding: .day, value: 1, to: startToday),
              let endWeek = calWrap.date(byAdding: .day, value: 7, to: startToday)
        else { return [] }

        let predToday = store.predicateForIncompleteReminders(
            withDueDateStarting: startToday,
            ending: endToday,
            calendars: [cal]
        )
        let predWeek = store.predicateForIncompleteReminders(
            withDueDateStarting: startToday,
            ending: endWeek,
            calendars: [cal]
        )

        let todayRems = try await fetchReminders(matching: predToday)
        let weekRems = try await fetchReminders(matching: predWeek)

        let routineToday = todayRems
            .filter { LineDogRoutineTag.notesContainRoutineMarker($0.notes) }
            .map(Self.mapReminder)

        let nonRoutineWeek = weekRems
            .filter { !LineDogRoutineTag.notesContainRoutineMarker($0.notes) }
            .map(Self.mapReminder)

        return DeskReminderSidebarMerger.mergedDisplayItems(
            routineToday: routineToday,
            nonRoutineWeek: nonRoutineWeek
        )
    }

    private func fetchReminders(matching predicate: NSPredicate) async throws -> [EKReminder] {
        try await withCheckedThrowingContinuation { cont in
            store.fetchReminders(matching: predicate) { list in
                cont.resume(returning: list ?? [])
            }
        }
    }

    private static func mapReminder(_ rem: EKReminder) -> ReminderDisplayItem {
        let due = rem.dueDateComponents.flatMap { Calendar.current.date(from: $0) }
        let hasTag = LineDogRoutineTag.notesContainRoutineMarker(rem.notes)
        return ReminderDisplayItem(
            calendarItemIdentifier: rem.calendarItemIdentifier,
            title: rem.title ?? "",
            dueDate: due,
            hasRoutineTag: hasTag
        )
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
