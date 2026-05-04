import Foundation

/// EventKit 变更防抖、乐观完成与内存队列合并；不持久化提醒内容。
@MainActor
final class RemindersSyncCoordinator {
    private(set) var items: [ReminderDisplayItem] = []
    private var optimisticCompletedIds: Set<String> = []
    private var debounceTask: Task<Void, Never>?

    private let backing: RemindersEventStoreBacking
    private let preference: RemindersSelectedListPreference
    let debounceInterval: TimeInterval

    var onItemsChanged: (([ReminderDisplayItem]) -> Void)?

    init(
        backing: RemindersEventStoreBacking,
        preference: RemindersSelectedListPreference = RemindersSelectedListPreference(),
        debounceInterval: TimeInterval = 0.6
    ) {
        self.backing = backing
        self.preference = preference
        self.debounceInterval = debounceInterval
    }

    /// `.EKEventStoreChanged` 等外部变更入口：合并防抖窗口，避免通知风暴。
    func scheduleReloadFromExternalChange() {
        debounceTask?.cancel()
        let delay = debounceInterval
        debounceTask = Task { [weak self] in
            guard let self else { return }
            let nanos = UInt64(delay * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
            guard !Task.isCancelled else { return }
            await self.reloadFromEventKit()
        }
    }

    func setSelectedCalendarIdentifier(_ id: String?) {
        preference.selectedCalendarIdentifier = id
    }

    func selectedCalendarIdentifier() -> String? {
        preference.selectedCalendarIdentifier
    }

    func reloadFromEventKit() async {
        guard let cid = preference.selectedCalendarIdentifier else {
            items = []
            onItemsChanged?(items)
            return
        }
        do {
            let fetched = try await backing.fetchDeskSidebarReminders(calendarId: cid)
            items = fetched.filter { !optimisticCompletedIds.contains($0.id) }
            onItemsChanged?(items)
        } catch {
            onItemsChanged?(items)
        }
    }

    /// 乐观 UI：立即从内存队列移除，再异步写 EventKit；失败则重新拉取恢复。
    func markComplete(id: String) async {
        items.removeAll { $0.id == id }
        optimisticCompletedIds.insert(id)
        onItemsChanged?(items)
        do {
            try await backing.completeReminder(calendarItemIdentifier: id)
            optimisticCompletedIds.remove(id)
        } catch {
            optimisticCompletedIds.remove(id)
            await reloadFromEventKit()
        }
        onItemsChanged?(items)
    }

    func loadReminderDetail(calendarItemIdentifier: String) async throws -> ReminderEditDetail {
        try await backing.loadReminderDetail(calendarItemIdentifier: calendarItemIdentifier)
    }

    func saveReminderDetail(_ detail: ReminderEditDetail) async throws {
        try await backing.saveReminderDetail(detail)
        await reloadFromEventKit()
    }

    func deleteReminder(id: String) async {
        items.removeAll { $0.id == id }
        onItemsChanged?(items)
        do {
            try await backing.deleteReminder(calendarItemIdentifier: id)
            await reloadFromEventKit()
        } catch {
            await reloadFromEventKit()
        }
        onItemsChanged?(items)
    }
}
