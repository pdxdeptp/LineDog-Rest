import Foundation
import SwiftUI

private final class RemindersExternalChangeEmitter {
    var handler: (() -> Void)?
    func fire() {
        handler?()
    }
}

/// 桌宠 / 菜单中的提醒事项区块；SSOT 为 EventKit，仅列表 id 存 UserDefaults。
@MainActor
final class DeskRemindersModel: ObservableObject {
    @Published private(set) var items: [ReminderDisplayItem] = []
    @Published private(set) var reminderLists: [RemindersCalendarDescriptor] = []
    @Published private(set) var isAuthorized = false
    @Published private(set) var statusMessage: String?

    /// 合并菜单栏与桌宠 Popover 同时 `.task` 触发的重复 `prepare`。
    private var inflightPrepare: Task<Void, Never>?

    private let externalChangeEmitter = RemindersExternalChangeEmitter()
    private let backing: RemindersEventStoreBacking
    private let coordinator: RemindersSyncCoordinator

    init(
        backing: RemindersEventStoreBacking? = nil,
        preference: RemindersSelectedListPreference = RemindersSelectedListPreference(),
        debounceInterval: TimeInterval = 0.6
    ) {
        let b = backing ?? EventKitRemindersBacking { [weak externalChangeEmitter] in
            Task { @MainActor in
                externalChangeEmitter?.fire()
            }
        }
        self.backing = b
        self.coordinator = RemindersSyncCoordinator(
            backing: b,
            preference: preference,
            debounceInterval: debounceInterval
        )
        coordinator.onItemsChanged = { [weak self] next in
            self?.items = next
        }
        externalChangeEmitter.handler = { [weak self] in
            self?.coordinator.scheduleReloadFromExternalChange()
        }
    }

    func prepare() async {
        if let existing = inflightPrepare {
            await existing.value
            return
        }
        let task = Task { @MainActor in
            await self.performPrepare()
        }
        inflightPrepare = task
        await task.value
        inflightPrepare = nil
    }

    private func performPrepare() async {
        statusMessage = nil
        do {
            let ok = try await backing.requestAccess()
            isAuthorized = ok
            guard ok else {
                statusMessage = "未授予提醒事项权限。"
                return
            }
            reminderLists = try await backing.fetchReminderCalendars()
            if coordinator.selectedCalendarIdentifier() == nil {
                coordinator.setSelectedCalendarIdentifier(
                    RemindersDefaultListResolver.preferredCalendarId(from: reminderLists)
                )
            }
            await coordinator.reloadFromEventKit()
        } catch {
            isAuthorized = false
            statusMessage = error.localizedDescription
        }
    }

    func selectList(calendarIdentifier: String) {
        coordinator.setSelectedCalendarIdentifier(calendarIdentifier)
        Task { await coordinator.reloadFromEventKit() }
    }

    func selectedListIdentifier() -> String? {
        coordinator.selectedCalendarIdentifier()
    }

    func completeReminder(id: String) async {
        await coordinator.markComplete(id: id)
    }
}
