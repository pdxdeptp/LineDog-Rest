import Foundation
@testable import LineDog

/// 单测用 EventKit 替身：记录调用次数与参数，可控延迟/失败。
final class MockRemindersEventStoreBacking: RemindersEventStoreBacking {
    var requestAccessResult = true
    var requestAccessError: Error?
    var calendars: [RemindersCalendarDescriptor] = []
    var fetchResult: [ReminderDisplayItem] = []
    private(set) var fetchCallCount = 0
    private(set) var lastFetchedCalendarId: String?
    var completeErrors: [String: Error] = [:]
    private(set) var completeCallOrder: [String] = []
    var completeDelayNanos: UInt64 = 0
    var fetchDelayNanos: UInt64 = 0

    var detailsById: [String: ReminderEditDetail] = [:]
    private(set) var loadCallOrder: [String] = []
    private(set) var savedDetails: [ReminderEditDetail] = []
    var saveErrors: [String: Error] = [:]
    private(set) var deleteCallOrder: [String] = []
    var deleteErrors: [String: Error] = [:]

    func requestAccess() async throws -> Bool {
        if let requestAccessError { throw requestAccessError }
        return requestAccessResult
    }

    func fetchReminderCalendars() async throws -> [RemindersCalendarDescriptor] {
        calendars
    }

    func fetchDeskSidebarReminders(calendarId: String) async throws -> [ReminderDisplayItem] {
        if fetchDelayNanos > 0 {
            try await Task.sleep(nanoseconds: fetchDelayNanos)
        }
        fetchCallCount += 1
        lastFetchedCalendarId = calendarId
        return fetchResult
    }

    func completeReminder(calendarItemIdentifier: String) async throws {
        if completeDelayNanos > 0 {
            try await Task.sleep(nanoseconds: completeDelayNanos)
        }
        completeCallOrder.append(calendarItemIdentifier)
        if let e = completeErrors[calendarItemIdentifier] {
            throw e
        }
    }

    func loadReminderDetail(calendarItemIdentifier: String) async throws -> ReminderEditDetail {
        loadCallOrder.append(calendarItemIdentifier)
        if let d = detailsById[calendarItemIdentifier] {
            return d
        }
        guard let item = fetchResult.first(where: { $0.id == calendarItemIdentifier }) else {
            throw NSError(domain: "MockReminders", code: 1, userInfo: [NSLocalizedDescriptionKey: "not found"])
        }
        return ReminderEditDetail(
            calendarItemIdentifier: item.calendarItemIdentifier,
            title: item.title,
            notesPlain: "",
            isRoutine: item.hasRoutineTag,
            dueDate: item.dueDate,
            includesTimeInDueDate: false
        )
    }

    func saveReminderDetail(_ detail: ReminderEditDetail) async throws {
        if let e = saveErrors[detail.calendarItemIdentifier] {
            throw e
        }
        savedDetails.append(detail)
        detailsById[detail.calendarItemIdentifier] = detail
        if let idx = fetchResult.firstIndex(where: { $0.id == detail.calendarItemIdentifier }) {
            fetchResult[idx] = ReminderDisplayItem(
                calendarItemIdentifier: detail.calendarItemIdentifier,
                title: detail.title,
                dueDate: detail.dueDate,
                hasRoutineTag: detail.isRoutine
            )
        }
    }

    func deleteReminder(calendarItemIdentifier: String) async throws {
        if let e = deleteErrors[calendarItemIdentifier] {
            throw e
        }
        deleteCallOrder.append(calendarItemIdentifier)
        fetchResult.removeAll { $0.id == calendarItemIdentifier }
        detailsById.removeValue(forKey: calendarItemIdentifier)
    }
}
