import EventKit
import Foundation

enum RemindersEventKitError: Error {
    case reminderNotFound
    case calendarNotWritable
}

/// 进程内唯一提醒用 `EKEventStore`。macOS 上多个实例时，未走「连接」的那一个常枚举不出日历，导致智能写入误判「无列表」。
enum MalDazeReminderEventStore {
    static let shared = EKEventStore()
}

/// 生产环境 EventKit 实现：监听 `.EKEventStoreChanged` 仅回调、不隐式写入。
final class EventKitRemindersBacking: NSObject, RemindersEventStoreBacking {
    private enum SidebarReminderWindowPolicy {
        static let forwardComponent = Calendar.Component.month
        static let forwardValue = 3
    }

    private let store: EKEventStore
    private let onExternalChange: @Sendable () -> Void

    init(
        store: EKEventStore = MalDazeReminderEventStore.shared,
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
              let upcomingWindowEnd = Self.upcomingReminderWindowExclusiveEnd(startOfToday: startToday, calendar: calWrap)
        else { return [] }

        // 与系统「提醒事项」一致：仅从今日起算的谓词拿不到「今天之前已到期但仍未完成」的条目，须另抓至 `startToday` 再合并。
        let predOverdue = store.predicateForIncompleteReminders(
            withDueDateStarting: .distantPast,
            ending: startToday,
            calendars: [cal]
        )
        let predToday = store.predicateForIncompleteReminders(
            withDueDateStarting: startToday,
            ending: endToday,
            calendars: [cal]
        )
        let predUpcomingWindow = store.predicateForIncompleteReminders(
            withDueDateStarting: startToday,
            ending: upcomingWindowEnd,
            calendars: [cal]
        )

        let overdueRems = try await fetchReminders(matching: predOverdue)
        let todayRems = try await fetchReminders(matching: predToday)
        let upcomingWindowRems = try await fetchReminders(matching: predUpcomingWindow)

        let overdueRoutine = overdueRems
            .filter { MalDazeRoutineTag.notesContainRoutineMarker($0.notes) }
            .map(Self.mapReminder)
        let overdueNonRoutine = overdueRems
            .filter { !MalDazeRoutineTag.notesContainRoutineMarker($0.notes) }
            .map(Self.mapReminder)

        let routineToday = todayRems
            .filter { MalDazeRoutineTag.notesContainRoutineMarker($0.notes) }
            .map(Self.mapReminder)

        // 不再按 routine 标签过滤未来窗口提醒：被推迟到其他日期的 #日常 项应正常展示。
        // mergedDisplayItems 已按 calendarItemIdentifier 去重，今日日常不会重复。
        let allUpcomingWindowMapped = upcomingWindowRems.map(Self.mapReminder)

        return DeskReminderSidebarMerger.mergedDisplayItems(
            routineToday: routineToday + overdueRoutine,
            nonRoutineUpcomingWindow: allUpcomingWindowMapped + overdueNonRoutine
        )
    }

    private static func upcomingReminderWindowExclusiveEnd(startOfToday: Date, calendar: Calendar) -> Date? {
        guard let targetDate = calendar.date(
            byAdding: SidebarReminderWindowPolicy.forwardComponent,
            value: SidebarReminderWindowPolicy.forwardValue,
            to: startOfToday
        ) else { return nil }
        return calendar.date(byAdding: .day, value: 1, to: targetDate)
    }

    private func fetchReminders(matching predicate: NSPredicate) async throws -> [EKReminder] {
        try await withCheckedThrowingContinuation { cont in
            store.fetchReminders(matching: predicate) { list in
                cont.resume(returning: list ?? [])
            }
        }
    }

    static func mapReminder(_ rem: EKReminder) -> ReminderDisplayItem {
        let dc = rem.dueDateComponents
        let due = dc.flatMap { Calendar.current.date(from: $0) }
        let hasTime = dc?.hour != nil || dc?.minute != nil
        let rawNotes = rem.notes ?? ""
        let hasTag = MalDazeRoutineTag.notesContainRoutineMarker(rem.notes)
        return ReminderDisplayItem(
            calendarItemIdentifier: rem.calendarItemIdentifier,
            title: rem.title ?? "",
            dueDate: due,
            hasExplicitTime: hasTime,
            hasRoutineTag: hasTag,
            notesPlain: Self.notesPlainByStrippingRoutineMarker(rawNotes)
        )
    }

    func completeReminder(calendarItemIdentifier: String) async throws {
        try await Self.runOnMainStore {
            guard let raw = $0.calendarItem(withIdentifier: calendarItemIdentifier),
                  let reminder = raw as? EKReminder
            else {
                throw RemindersEventKitError.reminderNotFound
            }
            reminder.isCompleted = true
            reminder.completionDate = Date()
            try $0.save(reminder, commit: true)
        }
    }

    func loadReminderDetail(calendarItemIdentifier: String) async throws -> ReminderEditDetail {
        try await Self.runOnMainStore { store in
            guard let raw = store.calendarItem(withIdentifier: calendarItemIdentifier),
                  let reminder = raw as? EKReminder
            else {
                throw RemindersEventKitError.reminderNotFound
            }
            return Self.editDetail(from: reminder)
        }
    }

    func saveReminderDetail(_ detail: ReminderEditDetail) async throws {
        try await Self.runOnMainStore { store in
            guard let raw = store.calendarItem(withIdentifier: detail.calendarItemIdentifier),
                  let reminder = raw as? EKReminder
            else {
                throw RemindersEventKitError.reminderNotFound
            }
            guard reminder.calendar?.allowsContentModifications == true else {
                throw RemindersEventKitError.calendarNotWritable
            }
            reminder.title = detail.title
            reminder.notes = Self.composedNotes(from: detail)
            Self.applyDueDateAndAlarms(from: detail, to: reminder)
            try Self.saveReminder(reminder, store: store)
        }
    }

    func deleteReminder(calendarItemIdentifier: String) async throws {
        try await Self.runOnMainStore { store in
            guard let raw = store.calendarItem(withIdentifier: calendarItemIdentifier),
                  let reminder = raw as? EKReminder
            else {
                throw RemindersEventKitError.reminderNotFound
            }
            guard reminder.calendar?.allowsContentModifications == true else {
                throw RemindersEventKitError.calendarNotWritable
            }
            try store.remove(reminder, commit: true)
        }
    }

    /// `EKEventStore` 写入与主线程一致，避免 macOS 上偶发空日历/保存失败。
    private static func runOnMainStore<T>(_ body: @escaping (EKEventStore) throws -> T) async throws -> T {
        try await MainActor.run {
            try body(MalDazeReminderEventStore.shared)
        }
    }

    private static func editDetail(from reminder: EKReminder) -> ReminderEditDetail {
        let rawNotes = reminder.notes ?? ""
        let isRoutine = MalDazeRoutineTag.notesContainRoutineMarker(rawNotes)
        let plain = Self.notesPlainByStrippingRoutineMarker(rawNotes)
        let dc = reminder.dueDateComponents
        let due = dc.flatMap { Calendar.current.date(from: $0) }
        let includesTime: Bool = {
            guard let dc else { return false }
            return dc.hour != nil || dc.minute != nil
        }()
        return ReminderEditDetail(
            calendarItemIdentifier: reminder.calendarItemIdentifier,
            title: reminder.title ?? "",
            notesPlain: plain,
            isRoutine: isRoutine,
            dueDate: due,
            includesTimeInDueDate: includesTime
        )
    }

    private static func notesPlainByStrippingRoutineMarker(_ notes: String) -> String {
        notes.split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { $0.trimmingCharacters(in: .whitespacesAndNewlines) != MalDazeRoutineTag.marker }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func composedNotes(from detail: ReminderEditDetail) -> String? {
        SmartReminderNotesComposer.finalizedNotes(
            llmNotes: detail.notesPlain.isEmpty ? nil : detail.notesPlain,
            isRoutine: detail.isRoutine
        )
    }

    private static func applyDueDateAndAlarms(from detail: ReminderEditDetail, to reminder: EKReminder) {
        if let existing = reminder.alarms {
            for alarm in existing {
                reminder.removeAlarm(alarm)
            }
        }
        if let due = detail.dueDate {
            var dc = Calendar.current.dateComponents([.year, .month, .day], from: due)
            dc.timeZone = Calendar.current.timeZone
            if detail.includesTimeInDueDate {
                dc.hour = Calendar.current.component(.hour, from: due)
                dc.minute = Calendar.current.component(.minute, from: due)
            }
            reminder.dueDateComponents = dc
            if detail.includesTimeInDueDate {
                reminder.addAlarm(EKAlarm(absoluteDate: due))
            }
        } else {
            reminder.dueDateComponents = nil
        }
    }

    private static func saveReminder(_ reminder: EKReminder, store: EKEventStore) throws {
        try store.save(reminder, commit: true)
    }
}
