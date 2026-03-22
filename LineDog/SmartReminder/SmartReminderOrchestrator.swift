import Foundation

/// 应用内铃铛：每条带闹钟的提醒单独调度。
struct SmartReminderInAppBell: Equatable {
    let itemIdentifier: String
    let fireDate: Date
    let message: String
}

/// 供气泡展示：文案 + 可撤销的 `calendarItemIdentifier`（空则隐藏撤销）。
struct SmartReminderRunResult: Equatable {
    let toastMessage: String
    /// 按创建顺序；撤销时全部删除。
    let undoItemIdentifiers: [String]
    let wasFallback: Bool
    let inAppBells: [SmartReminderInAppBell]
    /// 多条解析时仅部分写入成功；不应清空用户输入草稿。
    let incompleteMultiSave: Bool

    /// 首条 id（单条场景与旧测试兼容）。
    var undoItemIdentifier: String { undoItemIdentifiers.first ?? "" }
    /// 首条铃铛（兼容旧逻辑）。
    var inAppBellFireDate: Date? { inAppBells.first?.fireDate }
    var inAppBellMessage: String? { inAppBells.first?.message }

    init(
        toastMessage: String,
        undoItemIdentifiers: [String],
        wasFallback: Bool,
        inAppBells: [SmartReminderInAppBell] = [],
        incompleteMultiSave: Bool = false
    ) {
        self.toastMessage = toastMessage
        self.undoItemIdentifiers = undoItemIdentifiers
        self.wasFallback = wasFallback
        self.inAppBells = inAppBells
        self.incompleteMultiSave = incompleteMultiSave
    }
}

/// 用户原文里的「提醒我」等，模型常漏标 `has_alarm`。
private enum SmartReminderUserAlarmIntent {
    private static let phrases = [
        "提醒我", "记得提醒", "记得叫我", "到点提醒", "定时提醒",
        "闹钟", "叫我一下", "通知我", "响一下", "弹个提醒"
    ]

    static func mentionsTimedReminder(_ raw: String) -> Bool {
        phrases.contains { raw.contains($0) }
    }
}

/// 日常：有解析出的时间就默认带到时提醒；非日常：模型 `has_alarm` 或用户显式要提醒时才带闹钟。
private enum SmartReminderAlarmRouting {
    static func dueAndAlarm(
        payload: LLMReminderJSONPayload,
        routine: Bool,
        timeZone: TimeZone,
        rawUserInput: String
    ) -> (due: Date?, alarmAt: Date?) {
        let t = payload.dateFromAlarmFields(in: timeZone)
        guard let t else { return (nil, nil) }
        if routine {
            return (t, t)
        }
        if payload.has_alarm || SmartReminderUserAlarmIntent.mentionsTimedReminder(rawUserInput) {
            return (t, t)
        }
        return (t, nil)
    }
}

/// LLM → EventKit 编排；失败静默降级为纯文本标题（PRD 4.3）。
@MainActor
final class SmartReminderOrchestrator {
    private let gemini: GeminiRemindersGenerating
    private let mutation: ReminderMutationServing
    private let apiKeyProvider: () -> String?
    private let timeoutSeconds: TimeInterval

    /// 展示用上下文（与 Prompt 一致）
    private let timeZoneLabel: String
    private let cityRegionLabel: String

    init(
        gemini: GeminiRemindersGenerating = GeminiRemindersAPIClient(),
        mutation: ReminderMutationServing = EventKitReminderMutationService(),
        apiKeyProvider: @escaping () -> String?,
        timeZoneLabel: String = TimeZone.current.identifier,
        cityRegionLabel: String = "本地系统时区",
        timeoutSeconds: TimeInterval = 3.5
    ) {
        self.gemini = gemini
        self.mutation = mutation
        self.apiKeyProvider = apiKeyProvider
        self.timeZoneLabel = timeZoneLabel
        self.cityRegionLabel = cityRegionLabel
        self.timeoutSeconds = timeoutSeconds
    }

    /// 空输入返回 `nil`（不弹气泡）。
    /// - Parameter uiSelectedReminderListCalendarId: 左侧已选列表 id；在 EventKit 枚举偶发为空时作最后兜底。
    func run(rawUserInput: String, uiSelectedReminderListCalendarId: String? = nil) async -> SmartReminderRunResult? {
        let trimmed = rawUserInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let tz = TimeZone.current
        let now = Date()
        let calendars = (try? await mutation.fetchReminderCalendarsForMutation()) ?? []
        let titles = calendars.map { $0.1 }
        let system = SmartReminderPromptBuilder.systemPrompt(
            now: now,
            timeZone: tz,
            timeZoneLabel: timeZoneLabel,
            cityRegionLabel: cityRegionLabel,
            listTitles: titles
        )

        var parsedList: [LLMReminderJSONPayload] = []
        if let key = apiKeyProvider(), !key.isEmpty {
            let userMsg = SmartReminderPromptBuilder.userMessage(rawInput: trimmed)
            do {
                let jsonText = try await gemini.generateStructuredReminderJSON(
                    systemPrompt: system,
                    userText: userMsg,
                    apiKey: key,
                    timeoutSeconds: timeoutSeconds
                )
                SmartReminderModelDebugLog.appendExchange(
                    systemPrompt: system,
                    userText: userMsg,
                    modelRaw: jsonText
                )
                if let decoded = try? LLMReminderJSONDecoderService.decodePayloads(fromModelText: jsonText) {
                    parsedList = decoded.filter {
                        !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    }
                }
            } catch {
                SmartReminderModelDebugLog.appendExchange(
                    systemPrompt: system,
                    userText: userMsg,
                    modelRaw: "[请求失败] \(error.localizedDescription)"
                )
            }
        }

        let defaultListId = try? await mutation.defaultCalendarForNewRemindersIdentifier()

        if !parsedList.isEmpty {
            if parsedList.count == 1 {
                if let result = await saveParsedPayload(
                    parsedList[0],
                    rawUserInput: trimmed,
                    calendars: calendars,
                    timeZone: tz,
                    defaultNewRemindersId: defaultListId
                ) {
                    return result
                }
            } else if let result = await saveMultipleParsedPayloads(
                parsedList,
                rawUserInput: trimmed,
                calendars: calendars,
                timeZone: tz,
                defaultNewRemindersId: defaultListId
            ) {
                return result
            }
            // 已得到结构化 JSON 却选不到列表或 EventKit 保存失败时，不得再用整句原文当「普通备忘」冒充成功。
            return SmartReminderRunResult(
                toastMessage: "⚡️ 未能保存提醒（目标列表不可用或系统拒绝写入）",
                undoItemIdentifiers: [],
                wasFallback: true
            )
        }

        var calSnapshot = calendars
        if calSnapshot.isEmpty {
            calSnapshot = (try? await mutation.fetchReminderCalendarsForMutation()) ?? []
        }
        return await saveFallback(
            rawTitle: trimmed,
            calendars: calSnapshot,
            uiSelectedListCalendarId: uiSelectedReminderListCalendarId
        )
    }

    func removeReminder(calendarItemIdentifier: String) async throws {
        try await mutation.removeReminder(calendarItemIdentifier: calendarItemIdentifier)
    }

    private func saveParsedPayload(
        _ payload: LLMReminderJSONPayload,
        rawUserInput: String,
        calendars: [(String, String, Bool)],
        timeZone: TimeZone,
        defaultNewRemindersId: String?
    ) async -> SmartReminderRunResult? {
        let listName = Self.effectiveTargetListName(modelListName: payload.target_list_name, rawUserInput: rawUserInput)
        guard let calId = resolveCalendarIdentifier(
            targetListName: listName,
            calendars: calendars,
            defaultNewRemindersId: defaultNewRemindersId
        ) else {
            return nil
        }
        let p = payload.withInferredAlarmWallClock(rawUserInput: rawUserInput)
        let routine = SmartReminderRoutineInference.effectiveIsRoutine(
            llm: p.is_routine,
            rawUserInput: rawUserInput,
            reminderTitle: p.title
        )
        let (due, alarmAt) = SmartReminderAlarmRouting.dueAndAlarm(
            payload: p,
            routine: routine,
            timeZone: timeZone,
            rawUserInput: rawUserInput
        )
        let notes = SmartReminderNotesComposer.finalizedNotes(llmNotes: p.notes, isRoutine: routine)
        let recurrence = Self.reminderRecurrenceSpec(from: p.recurrence)
        do {
            let id = try await mutation.createReminder(
                title: p.title,
                notes: notes,
                calendarIdentifier: calId,
                dueDate: due,
                alarmAt: alarmAt,
                priority: clampPriority(p.priority),
                recurrence: recurrence
            )
            var msg = routine ? "✅ 已添加 [日常]" : "✅ 已添加"
            if recurrence != nil {
                msg += "（重复）"
            }
            let trimmedTitle = p.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let bellLine = trimmedTitle.isEmpty ? "提醒事项" : trimmedTitle
            let bells: [SmartReminderInAppBell]
            if let alarmAt {
                bells = [SmartReminderInAppBell(itemIdentifier: id, fireDate: alarmAt, message: bellLine)]
            } else {
                bells = []
            }
            return SmartReminderRunResult(
                toastMessage: msg,
                undoItemIdentifiers: [id],
                wasFallback: false,
                inAppBells: bells
            )
        } catch {
            return nil
        }
    }

    private func saveMultipleParsedPayloads(
        _ items: [LLMReminderJSONPayload],
        rawUserInput: String,
        calendars: [(String, String, Bool)],
        timeZone: TimeZone,
        defaultNewRemindersId: String?
    ) async -> SmartReminderRunResult? {
        var ids: [String] = []
        var bells: [SmartReminderInAppBell] = []
        var anyRoutine = false
        var anyRecurrence = false
        for p in items {
            guard let one = await saveParsedPayload(
                p,
                rawUserInput: rawUserInput,
                calendars: calendars,
                timeZone: timeZone,
                defaultNewRemindersId: defaultNewRemindersId
            ) else {
                if ids.isEmpty { return nil }
                return SmartReminderRunResult(
                    toastMessage: "✅ 已添加 \(ids.count) 项（另有 \(items.count - ids.count) 项未能写入）",
                    undoItemIdentifiers: ids,
                    wasFallback: false,
                    inAppBells: bells,
                    incompleteMultiSave: true
                )
            }
            ids.append(contentsOf: one.undoItemIdentifiers)
            bells.append(contentsOf: one.inAppBells)
            anyRoutine = anyRoutine || one.toastMessage.contains("[日常]")
            anyRecurrence = anyRecurrence || one.toastMessage.contains("（重复）")
        }
        var msg = "✅ 已添加 \(ids.count) 项"
        if anyRoutine { msg += " [日常]" }
        if anyRecurrence { msg += "（重复）" }
        return SmartReminderRunResult(
            toastMessage: msg,
            undoItemIdentifiers: ids,
            wasFallback: false,
            inAppBells: bells
        )
    }

    private func saveFallback(
        rawTitle: String,
        calendars: [(String, String, Bool)],
        uiSelectedListCalendarId: String?
    ) async -> SmartReminderRunResult {
        let defId =
            (try? await mutation.defaultCalendarForNewRemindersIdentifier())
                ?? calendars.first(where: { $0.2 })?.0
                ?? calendars.first?.0
                ?? uiSelectedListCalendarId
        guard let calId = defId else {
            return SmartReminderRunResult(
                toastMessage: "⚡️ 未能定位提醒列表（EventKit 未返回日历）",
                undoItemIdentifiers: [],
                wasFallback: true
            )
        }
        do {
            let id = try await mutation.createReminder(
                title: rawTitle,
                notes: nil,
                calendarIdentifier: calId,
                dueDate: nil,
                alarmAt: nil,
                priority: 0,
                recurrence: nil
            )
            return SmartReminderRunResult(
                toastMessage: "⚡️ 存为普通备忘",
                undoItemIdentifiers: [id],
                wasFallback: true
            )
        } catch {
            return SmartReminderRunResult(
                toastMessage: "⚡️ 无法写入提醒事项",
                undoItemIdentifiers: [],
                wasFallback: true
            )
        }
    }

    /// 模型常误填 `Inbox`；未点名收件箱时改回 `Reminders`，与产品默认一致。
    private static func effectiveTargetListName(modelListName: String, rawUserInput: String) -> String {
        let name = modelListName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.caseInsensitiveCompare("Inbox") == .orderedSame else {
            return name
        }
        if userExplicitlyRequestedInbox(rawUserInput) {
            return "Inbox"
        }
        return "Reminders"
    }

    private static func userExplicitlyRequestedInbox(_ raw: String) -> Bool {
        let lower = raw.lowercased()
        if lower.contains("收件箱") { return true }
        if lower.contains("inbox") { return true }
        if lower.contains("默认列表") { return true }
        return false
    }

    private func resolveCalendarIdentifier(
        targetListName: String,
        calendars: [(String, String, Bool)],
        defaultNewRemindersId: String?
    ) -> String? {
        let writable = calendars.filter { $0.2 }
        let lower = targetListName.lowercased()
        if lower == "inbox" {
            if let id = defaultNewRemindersId,
               writable.contains(where: { $0.0 == id }) {
                return id
            }
            return writable.first?.0
                ?? calendars.first(where: { $0.2 })?.0
        }
        if let m = writable.first(where: { $0.1.caseInsensitiveCompare(targetListName) == .orderedSame }) {
            return m.0
        }
        if let m = writable.first(where: { $0.1.localizedCaseInsensitiveContains(targetListName) }) {
            return m.0
        }
        return writable.first?.0
            ?? calendars.first(where: { $0.2 })?.0
    }

    private func clampPriority(_ p: Int) -> Int {
        if [0, 1, 5, 9].contains(p) { return p }
        return 0
    }

    /// 将模型 `recurrence` 转为写入 EventKit 的规格；`frequency` 为 `none`/空则 nil。
    private static func reminderRecurrenceSpec(from r: LLMReminderJSONPayload.RecurrenceFields?) -> ReminderRecurrenceSpec? {
        guard let r else { return nil }
        let raw = (r.frequency ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !raw.isEmpty, raw != "none" else { return nil }
        let interval = max(1, r.interval ?? 1)
        switch raw {
        case "daily", "day":
            return ReminderRecurrenceSpec(frequency: .daily, interval: interval, daysOfTheWeek: nil, dayOfMonth: nil)
        case "weekly", "week":
            return ReminderRecurrenceSpec(
                frequency: .weekly,
                interval: interval,
                daysOfTheWeek: r.days_of_week,
                dayOfMonth: nil
            )
        case "monthly", "month":
            return ReminderRecurrenceSpec(
                frequency: .monthly,
                interval: interval,
                daysOfTheWeek: nil,
                dayOfMonth: r.day_of_month
            )
        case "yearly", "year", "annual":
            return ReminderRecurrenceSpec(frequency: .yearly, interval: interval, daysOfTheWeek: nil, dayOfMonth: nil)
        default:
            return nil
        }
    }

}
