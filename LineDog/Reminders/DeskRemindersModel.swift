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
    /// 编辑 / 删除 / 推迟 等写操作失败时的简短说明（成功后会清空）。
    @Published private(set) var mutationMessage: String?

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
            // #region agent log
            LineDogAgentDebugNDJSON.log(
                hypothesisId: "H2",
                location: "DeskRemindersModel.swift:performPrepare",
                message: "before_activateEphemeralKeyWindow"
            )
            // #endregion
            LineDogModalKeyWindowAnchor.activateEphemeralKeyWindowForSystemModal()
            defer { LineDogModalKeyWindowAnchor.removeEphemeralKeyWindow() }
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

    func loadReminderForEdit(id: String) async throws -> ReminderEditDetail {
        try await coordinator.loadReminderDetail(calendarItemIdentifier: id)
    }

    func saveReminderEdit(_ detail: ReminderEditDetail) async {
        mutationMessage = nil
        do {
            try await coordinator.saveReminderDetail(detail)
        } catch {
            mutationMessage = error.localizedDescription
        }
    }

    func deleteReminder(id: String) async {
        mutationMessage = nil
        await coordinator.deleteReminder(id: id)
    }

    /// 在现有截止日期上顺延 `days`；无截止日期时设为「今天起第 `days` 天」上午 9:00。
    func postponeReminder(id: String, addingDays days: Int) async {
        mutationMessage = nil
        do {
            var detail = try await coordinator.loadReminderDetail(calendarItemIdentifier: id)
            let cal = Calendar.current
            if let due = detail.dueDate {
                guard let shifted = cal.date(byAdding: .day, value: days, to: due) else { return }
                detail.dueDate = shifted
            } else {
                let start = cal.startOfDay(for: Date())
                guard let base = cal.date(byAdding: .day, value: days, to: start) else { return }
                detail.dueDate = cal.date(bySettingHour: 9, minute: 0, second: 0, of: base) ?? base
                detail.includesTimeInDueDate = true
            }
            try await coordinator.saveReminderDetail(detail)
        } catch {
            mutationMessage = error.localizedDescription
        }
    }

    /// 截止日期改为「明天」：有时刻则保留钟点；仅日期则明天全天；无截止日期则明天 9:00。
    func postponeReminderToTomorrow(id: String) async {
        mutationMessage = nil
        do {
            var detail = try await coordinator.loadReminderDetail(calendarItemIdentifier: id)
            let cal = Calendar.current
            let todayStart = cal.startOfDay(for: Date())
            guard let tomorrowStart = cal.date(byAdding: .day, value: 1, to: todayStart) else { return }
            if detail.includesTimeInDueDate, let due = detail.dueDate {
                let h = cal.component(.hour, from: due)
                let m = cal.component(.minute, from: due)
                detail.dueDate = cal.date(bySettingHour: h, minute: m, second: 0, of: tomorrowStart) ?? tomorrowStart
            } else if detail.dueDate != nil {
                detail.dueDate = tomorrowStart
                detail.includesTimeInDueDate = false
            } else {
                detail.dueDate = cal.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrowStart) ?? tomorrowStart
                detail.includesTimeInDueDate = true
            }
            try await coordinator.saveReminderDetail(detail)
        } catch {
            mutationMessage = error.localizedDescription
        }
    }

    func clearMutationMessage() {
        mutationMessage = nil
    }
}
