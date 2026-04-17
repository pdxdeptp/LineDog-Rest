import EventKit
import Foundation

enum RemindersEventKitError: Error {
    case reminderNotFound
    case calendarNotWritable
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
        let predWeek = store.predicateForIncompleteReminders(
            withDueDateStarting: startToday,
            ending: endWeek,
            calendars: [cal]
        )

        let overdueRems = try await fetchReminders(matching: predOverdue)
        let todayRems = try await fetchReminders(matching: predToday)
        let weekRems = try await fetchReminders(matching: predWeek)

        // #region agent log
        for (label, rems) in [("overdue", overdueRems), ("today", todayRems), ("week", weekRems)] {
            for rem in rems {
                let dc = rem.dueDateComponents
                let hasTime = dc?.hour != nil || dc?.minute != nil
                LineDogAgentDebugNDJSON.log(
                    hypothesisId: "H-A/B/C",
                    location: "EventKitRemindersBacking.swift:fetchDeskSidebarReminders",
                    message: "fetched_reminder",
                    data: [
                        "bucket": label,
                        "title": rem.title ?? "nil",
                        "hasTime": "\(hasTime)",
                        "y": "\(dc?.year ?? -1)", "m": "\(dc?.month ?? -1)", "d": "\(dc?.day ?? -1)",
                        "h": "\(dc?.hour as Any)", "min": "\(dc?.minute as Any)",
                        "dateFromDC": "\(dc.flatMap { Calendar.current.date(from: $0) } as Any)"
                    ],
                    runId: "h-abcd"
                )
            }
            if rems.isEmpty {
                LineDogAgentDebugNDJSON.log(
                    hypothesisId: "H-A",
                    location: "EventKitRemindersBacking.swift:fetchDeskSidebarReminders",
                    message: "bucket_empty",
                    data: ["bucket": label],
                    runId: "h-abcd"
                )
            }
        }
        // #endregion

        let overdueRoutine = overdueRems
            .filter { LineDogRoutineTag.notesContainRoutineMarker($0.notes) }
            .map(Self.mapReminder)
        let overdueNonRoutine = overdueRems
            .filter { !LineDogRoutineTag.notesContainRoutineMarker($0.notes) }
            .map(Self.mapReminder)

        let routineToday = todayRems
            .filter { LineDogRoutineTag.notesContainRoutineMarker($0.notes) }
            .map(Self.mapReminder)

        // 不再按 routine 标签过滤 weekRems：被推迟到本周其他日期的 #日常 项应正常展示。
        // mergedDisplayItems 已按 calendarItemIdentifier 去重，今日日常不会重复。
        let allWeekMapped = weekRems.map(Self.mapReminder)

        return DeskReminderSidebarMerger.mergedDisplayItems(
            routineToday: routineToday + overdueRoutine,
            nonRoutineWeek: allWeekMapped + overdueNonRoutine
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
        let dc = rem.dueDateComponents
        let due = dc.flatMap { Calendar.current.date(from: $0) }
        let hasTime = dc?.hour != nil || dc?.minute != nil
        let hasTag = LineDogRoutineTag.notesContainRoutineMarker(rem.notes)
        return ReminderDisplayItem(
            calendarItemIdentifier: rem.calendarItemIdentifier,
            title: rem.title ?? "",
            dueDate: due,
            hasExplicitTime: hasTime,
            hasRoutineTag: hasTag
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
            try body(LineDogReminderEventStore.shared)
        }
    }

    private static func editDetail(from reminder: EKReminder) -> ReminderEditDetail {
        let rawNotes = reminder.notes ?? ""
        let isRoutine = LineDogRoutineTag.notesContainRoutineMarker(rawNotes)
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
            .filter { $0.trimmingCharacters(in: .whitespacesAndNewlines) != LineDogRoutineTag.marker }
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
