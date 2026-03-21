import Foundation

/// 供气泡展示：文案 + 可撤销的 `calendarItemIdentifier`（空则隐藏撤销）。
struct SmartReminderRunResult: Equatable {
    let toastMessage: String
    let undoItemIdentifier: String
    let wasFallback: Bool
    /// 与写入的 `EKAlarm` 时刻一致；主线程可在该时刻弹出与 7 分钟倒计时结束相同的中央铃铛。
    let inAppBellFireDate: Date?
    /// 到点时中央面板展示的正文（一般为提醒标题）。
    let inAppBellMessage: String?

    init(
        toastMessage: String,
        undoItemIdentifier: String,
        wasFallback: Bool,
        inAppBellFireDate: Date? = nil,
        inAppBellMessage: String? = nil
    ) {
        self.toastMessage = toastMessage
        self.undoItemIdentifier = undoItemIdentifier
        self.wasFallback = wasFallback
        self.inAppBellFireDate = inAppBellFireDate
        self.inAppBellMessage = inAppBellMessage
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

        var parsed: LLMReminderJSONPayload?
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
                parsed = try? LLMReminderJSONDecoderService.decode(fromModelText: jsonText)
            } catch {
                SmartReminderModelDebugLog.appendExchange(
                    systemPrompt: system,
                    userText: userMsg,
                    modelRaw: "[请求失败] \(error.localizedDescription)"
                )
            }
        }

        let defaultListId = try? await mutation.defaultCalendarForNewRemindersIdentifier()

        if let p = parsed {
            if let result = await saveParsedPayload(
                p,
                rawUserInput: trimmed,
                calendars: calendars,
                timeZone: tz,
                defaultNewRemindersId: defaultListId
            ) {
                return result
            }
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
        _ p: LLMReminderJSONPayload,
        rawUserInput: String,
        calendars: [(String, String, Bool)],
        timeZone: TimeZone,
        defaultNewRemindersId: String?
    ) async -> SmartReminderRunResult? {
        guard let calId = resolveCalendarIdentifier(
            targetListName: p.target_list_name,
            calendars: calendars,
            defaultNewRemindersId: defaultNewRemindersId
        ) else {
            return nil
        }
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
        do {
            let id = try await mutation.createReminder(
                title: p.title,
                notes: notes,
                calendarIdentifier: calId,
                dueDate: due,
                alarmAt: alarmAt,
                priority: clampPriority(p.priority)
            )
            let msg = routine ? "✅ 已添加 [日常]" : "✅ 已添加"
            let trimmedTitle = p.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let bellLine = trimmedTitle.isEmpty ? "提醒事项" : trimmedTitle
            return SmartReminderRunResult(
                toastMessage: msg,
                undoItemIdentifier: id,
                wasFallback: false,
                inAppBellFireDate: alarmAt,
                inAppBellMessage: alarmAt != nil ? bellLine : nil
            )
        } catch {
            return nil
        }
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
                undoItemIdentifier: "",
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
                priority: 0
            )
            return SmartReminderRunResult(
                toastMessage: "⚡️ 存为普通备忘",
                undoItemIdentifier: id,
                wasFallback: true
            )
        } catch {
            return SmartReminderRunResult(
                toastMessage: "⚡️ 存为普通备忘",
                undoItemIdentifier: "",
                wasFallback: true
            )
        }
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

}
