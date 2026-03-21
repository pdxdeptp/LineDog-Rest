import Foundation

/// 供气泡展示：文案 + 可撤销的 `calendarItemIdentifier`（空则隐藏撤销）。
struct SmartReminderRunResult: Equatable {
    let toastMessage: String
    let undoItemIdentifier: String
    let wasFallback: Bool
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
    func run(rawUserInput: String) async -> SmartReminderRunResult? {
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
            if let jsonText = try? await gemini.generateStructuredReminderJSON(
                systemPrompt: system,
                userText: SmartReminderPromptBuilder.userMessage(rawInput: trimmed),
                apiKey: key,
                timeoutSeconds: timeoutSeconds
            ) {
                parsed = try? LLMReminderJSONDecoderService.decode(fromModelText: jsonText)
            }
        }

        let defaultListId = try? await mutation.defaultCalendarForNewRemindersIdentifier()

        if let p = parsed {
            if let result = await saveParsedPayload(
                p,
                calendars: calendars,
                timeZone: tz,
                defaultNewRemindersId: defaultListId
            ) {
                return result
            }
        }

        return await saveFallback(rawTitle: trimmed, calendars: calendars)
    }

    func removeReminder(calendarItemIdentifier: String) async throws {
        try await mutation.removeReminder(calendarItemIdentifier: calendarItemIdentifier)
    }

    private func saveParsedPayload(
        _ p: LLMReminderJSONPayload,
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
        let alarm = p.alarmDate(in: timeZone)
        do {
            let id = try await mutation.createReminder(
                title: p.title,
                notes: p.notes,
                calendarIdentifier: calId,
                alarmDate: alarm,
                priority: clampPriority(p.priority)
            )
            let when = formatAlarmSummary(alarm, timeZone: timeZone)
            let msg = when.isEmpty
                ? "✅ 已添加：\(p.title)"
                : "✅ 已添加：\(p.title) (\(when))"
            return SmartReminderRunResult(toastMessage: msg, undoItemIdentifier: id, wasFallback: false)
        } catch {
            return nil
        }
    }

    private func saveFallback(
        rawTitle: String,
        calendars: [(String, String, Bool)]
    ) async -> SmartReminderRunResult {
        let defId =
            (try? await mutation.defaultCalendarForNewRemindersIdentifier())
                ?? calendars.first(where: { $0.2 })?.0
                ?? calendars.first?.0
        guard let calId = defId else {
            return SmartReminderRunResult(
                toastMessage: "⚡️ 无法写入提醒事项（无可用列表）",
                undoItemIdentifier: "",
                wasFallback: true
            )
        }
        do {
            let id = try await mutation.createReminder(
                title: rawTitle,
                notes: nil,
                calendarIdentifier: calId,
                alarmDate: nil,
                priority: 0
            )
            return SmartReminderRunResult(
                toastMessage: "⚡️ 网络开小差了，已作为普通文本存入备忘",
                undoItemIdentifier: id,
                wasFallback: true
            )
        } catch {
            return SmartReminderRunResult(
                toastMessage: "⚡️ 网络开小差了，已作为普通文本存入备忘",
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

    private func formatAlarmSummary(_ date: Date?, timeZone: TimeZone) -> String {
        guard let date else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.timeZone = timeZone
        f.dateFormat = "M月d日 HH:mm"
        return f.string(from: date)
    }
}
