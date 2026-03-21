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
}
