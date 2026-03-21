import XCTest

@testable import LineDog

@MainActor
final class SmartReminderOrchestratorTests: XCTestCase {
    private let sampleJSON = """
    {"title":"发邮件","is_routine":false,"notes":null,"target_list_name":"工作","has_alarm":true,"alarm_date":{"year":2030,"month":6,"day":10,"hour":15,"minute":30},"priority":0}
    """

    func testDecodeValidJSONWithFence() throws {
        let wrapped = "```json\n\(sampleJSON)\n```"
        let p = try LLMReminderJSONDecoderService.decode(fromModelText: wrapped)
        XCTAssertEqual(p.title, "发邮件")
        XCTAssertFalse(p.is_routine)
        XCTAssertEqual(p.target_list_name, "工作")
        XCTAssertTrue(p.has_alarm)
        XCTAssertEqual(p.alarm_date?.hour, 15)
    }

    func testDecodeOmittedIsRoutineDefaultsToFalse() throws {
        let json = """
        {"title":"x","notes":null,"target_list_name":"工作","has_alarm":false,"priority":0}
        """
        let p = try LLMReminderJSONDecoderService.decode(fromModelText: json)
        XCTAssertFalse(p.is_routine)
    }

    func testDecodeAlarmDateAsISO8601String() throws {
        let json = """
        {"title":"收衣服","is_routine":true,"notes":null,"target_list_name":"Reminders","has_alarm":false,"alarm_date":"2026-03-21T19:10:00-04:00","priority":0}
        """
        let p = try LLMReminderJSONDecoderService.decode(fromModelText: json)
        XCTAssertEqual(p.title, "收衣服")
        XCTAssertTrue(p.is_routine)
        XCTAssertNotNil(p.alarm_date)
        XCTAssertNotNil(p.dateFromAlarmFields(in: TimeZone.current))
    }

    func testDecodeCamelCaseIsRoutine() throws {
        let json = """
        {"title":"吃药","isRoutine":true,"notes":null,"targetListName":"工作","hasAlarm":false,"priority":0}
        """
        let p = try LLMReminderJSONDecoderService.decode(fromModelText: json)
        XCTAssertTrue(p.is_routine)
        XCTAssertEqual(p.target_list_name, "工作")
        XCTAssertFalse(p.has_alarm)
    }

    func testOrchestratorSavesParsedReminderWhenGeminiOK() async {
        let gemini = MockGeminiRemindersClient()
        gemini.textToReturn = sampleJSON
        let mutation = MockReminderMutationService()
        mutation.calendars = [("cal-work", "工作", true)]
        mutation.defaultCalendarId = "cal-work"

        let orch = SmartReminderOrchestrator(
            gemini: gemini,
            mutation: mutation,
            apiKeyProvider: { "fake-key" },
            timeZoneLabel: "America/New_York",
            cityRegionLabel: "TestCity",
            timeoutSeconds: 3.5
        )

        let r = await orch.run(rawUserInput: "明天下午三点半发邮件")
        XCTAssertNotNil(r)
        XCTAssertFalse(r!.wasFallback)
        XCTAssertEqual(r!.toastMessage, "✅ 已添加")
        XCTAssertFalse(r!.undoItemIdentifier.isEmpty)
        XCTAssertEqual(mutation.lastCreateTitle, "发邮件")
        XCTAssertNil(mutation.lastCreateNotes)
        XCTAssertNotNil(mutation.lastCreateDue)
        XCTAssertNotNil(mutation.lastCreateAlarm)
        XCTAssertNotNil(r!.inAppBellFireDate)
    }

    func testChoreHintAddsRoutineWhenLLMSaysFalse() async {
        let gemini = MockGeminiRemindersClient()
        gemini.textToReturn = """
        {"title":"收衣服","is_routine":false,"notes":null,"target_list_name":"工作","has_alarm":true,"alarm_date":{"year":2030,"month":6,"day":10,"hour":15,"minute":0},"priority":0}
        """
        let mutation = MockReminderMutationService()
        mutation.calendars = [("cal-work", "工作", true)]
        mutation.defaultCalendarId = "cal-work"

        let orch = SmartReminderOrchestrator(
            gemini: gemini,
            mutation: mutation,
            apiKeyProvider: { "k" },
            timeZoneLabel: "UTC",
            cityRegionLabel: "X"
        )

        let r = await orch.run(rawUserInput: "一小时后收衣服")
        XCTAssertEqual(r?.toastMessage, "✅ 已添加 [日常]")
        XCTAssertEqual(mutation.lastCreateNotes, "#日常")
        XCTAssertNotNil(mutation.lastCreateAlarm)
        XCTAssertNotNil(r?.inAppBellFireDate)
    }

    func testNonRoutineUserSaysRemindMeForcesAlarmEvenIfModelHasAlarmFalse() async {
        let gemini = MockGeminiRemindersClient()
        gemini.textToReturn = """
        {"title":"交报告","is_routine":false,"notes":null,"target_list_name":"工作","has_alarm":false,"alarm_date":{"year":2030,"month":7,"day":1,"hour":18,"minute":0},"priority":0}
        """
        let mutation = MockReminderMutationService()
        mutation.calendars = [("cal-work", "工作", true)]
        mutation.defaultCalendarId = "cal-work"

        let orch = SmartReminderOrchestrator(
            gemini: gemini,
            mutation: mutation,
            apiKeyProvider: { "k" },
            timeZoneLabel: "UTC",
            cityRegionLabel: "X"
        )

        let r = await orch.run(rawUserInput: "7月1日下午六点前提醒我交报告")
        XCTAssertEqual(r?.toastMessage, "✅ 已添加")
        XCTAssertNotNil(mutation.lastCreateDue)
        XCTAssertNotNil(mutation.lastCreateAlarm)
        XCTAssertNotNil(r?.inAppBellFireDate)
    }

    func testNonRoutineNoAlarmIntentSetsDueOnly() async {
        let gemini = MockGeminiRemindersClient()
        gemini.textToReturn = """
        {"title":"交报告","is_routine":false,"notes":null,"target_list_name":"工作","has_alarm":false,"alarm_date":{"year":2030,"month":7,"day":1,"hour":18,"minute":0},"priority":0}
        """
        let mutation = MockReminderMutationService()
        mutation.calendars = [("cal-work", "工作", true)]
        mutation.defaultCalendarId = "cal-work"

        let orch = SmartReminderOrchestrator(
            gemini: gemini,
            mutation: mutation,
            apiKeyProvider: { "k" },
            timeZoneLabel: "UTC",
            cityRegionLabel: "X"
        )

        let r = await orch.run(rawUserInput: "7月1日前交报告")
        XCTAssertEqual(r?.toastMessage, "✅ 已添加")
        XCTAssertNotNil(mutation.lastCreateDue)
        XCTAssertNil(mutation.lastCreateAlarm)
        XCTAssertNil(r?.inAppBellFireDate)
    }

    func testRoutineAddsAlarmEvenIfModelSetsHasAlarmFalse() async {
        let gemini = MockGeminiRemindersClient()
        gemini.textToReturn = """
        {"title":"吃药","is_routine":true,"notes":null,"target_list_name":"工作","has_alarm":false,"alarm_date":{"year":2030,"month":6,"day":10,"hour":8,"minute":0},"priority":0}
        """
        let mutation = MockReminderMutationService()
        mutation.calendars = [("cal-work", "工作", true)]
        mutation.defaultCalendarId = "cal-work"

        let orch = SmartReminderOrchestrator(
            gemini: gemini,
            mutation: mutation,
            apiKeyProvider: { "k" },
            timeZoneLabel: "UTC",
            cityRegionLabel: "X"
        )

        let r = await orch.run(rawUserInput: "早八点吃药")
        XCTAssertEqual(r?.toastMessage, "✅ 已添加 [日常]")
        XCTAssertNotNil(mutation.lastCreateAlarm)
        XCTAssertNotNil(r?.inAppBellFireDate)
    }

    func testRoutineAddsTagAndToast() async {
        let gemini = MockGeminiRemindersClient()
        gemini.textToReturn = """
        {"title":"吃药","is_routine":true,"notes":"饭后","target_list_name":"工作","has_alarm":true,"alarm_date":{"year":2030,"month":6,"day":10,"hour":8,"minute":0},"priority":0}
        """
        let mutation = MockReminderMutationService()
        mutation.calendars = [("cal-work", "工作", true)]
        mutation.defaultCalendarId = "cal-work"

        let orch = SmartReminderOrchestrator(
            gemini: gemini,
            mutation: mutation,
            apiKeyProvider: { "k" },
            timeZoneLabel: "UTC",
            cityRegionLabel: "X"
        )

        let r = await orch.run(rawUserInput: "每天早上八点吃药")
        XCTAssertEqual(r?.toastMessage, "✅ 已添加 [日常]")
        XCTAssertEqual(mutation.lastCreateNotes, "饭后\n#日常")
    }

    func testEmptyApiKeyFallsBackToRawTitle() async {
        let gemini = MockGeminiRemindersClient()
        gemini.textToReturn = sampleJSON
        let mutation = MockReminderMutationService()
        mutation.calendars = [("cal1", "Inbox", true)]
        mutation.defaultCalendarId = "cal1"

        let orch = SmartReminderOrchestrator(
            gemini: gemini,
            mutation: mutation,
            apiKeyProvider: { "" },
            timeZoneLabel: "UTC",
            cityRegionLabel: "X"
        )

        let r = await orch.run(rawUserInput: "原始整句备忘")
        XCTAssertNotNil(r)
        XCTAssertTrue(r!.wasFallback)
        XCTAssertEqual(r!.toastMessage, "⚡️ 存为普通备忘")
        XCTAssertEqual(mutation.lastCreateTitle, "原始整句备忘")
        XCTAssertNil(mutation.lastCreateDue)
        XCTAssertNil(mutation.lastCreateAlarm)
    }

    func testGeminiFailureFallsBack() async {
        let gemini = MockGeminiRemindersClient()
        gemini.shouldThrow = true
        let mutation = MockReminderMutationService()
        mutation.calendars = [("cal1", "工作", true)]
        mutation.defaultCalendarId = "cal1"

        let orch = SmartReminderOrchestrator(
            gemini: gemini,
            mutation: mutation,
            apiKeyProvider: { "k" },
            timeZoneLabel: "UTC",
            cityRegionLabel: "X"
        )

        let r = await orch.run(rawUserInput: "网络会挂的句子")
        XCTAssertNotNil(r)
        XCTAssertTrue(r!.wasFallback)
        XCTAssertEqual(mutation.lastCreateTitle, "网络会挂的句子")
        XCTAssertEqual(r!.toastMessage, "⚡️ 存为普通备忘")
    }

    func testRunReturnsNilForWhitespaceOnly() async {
        let orch = SmartReminderOrchestrator(
            gemini: MockGeminiRemindersClient(),
            mutation: MockReminderMutationService(),
            apiKeyProvider: { nil }
        )
        let r = await orch.run(rawUserInput: "   \n")
        XCTAssertNil(r)
    }

    func testInboxUsesDefaultCalendarWhenWritable() async {
        let gemini = MockGeminiRemindersClient()
        gemini.textToReturn = """
        {"title":"T","is_routine":false,"notes":null,"target_list_name":"Inbox","has_alarm":false,"alarm_date":null,"priority":0}
        """
        let mutation = MockReminderMutationService()
        mutation.calendars = [
            ("other", "其它", true),
            ("def", "默认", true)
        ]
        mutation.defaultCalendarId = "def"

        let orch = SmartReminderOrchestrator(
            gemini: gemini,
            mutation: mutation,
            apiKeyProvider: { "k" },
            timeZoneLabel: "UTC",
            cityRegionLabel: "X"
        )

        _ = await orch.run(rawUserInput: "x")
        XCTAssertEqual(mutation.lastCreateCalendarId, "def")
    }
}

// MARK: - Mocks

private final class MockGeminiRemindersClient: GeminiRemindersGenerating {
    var textToReturn: String?
    var shouldThrow = false

    func generateStructuredReminderJSON(
        systemPrompt: String,
        userText: String,
        apiKey: String,
        timeoutSeconds: TimeInterval
    ) async throws -> String {
        if shouldThrow { throw URLError(.timedOut) }
        return textToReturn ?? ""
    }
}

private final class MockReminderMutationService: ReminderMutationServing {
    var calendars: [(String, String, Bool)] = []
    var defaultCalendarId: String?
    private(set) var lastCreateTitle: String?
    private(set) var lastCreateNotes: String?
    private(set) var lastCreateCalendarId: String?
    private(set) var lastCreateDue: Date?
    private(set) var lastCreateAlarm: Date?
    private(set) var lastCreatePriority: Int?
    private var nextId = 1

    func fetchReminderCalendarsForMutation() async throws -> [(String, String, Bool)] {
        calendars
    }

    func defaultCalendarForNewRemindersIdentifier() async throws -> String? {
        defaultCalendarId
    }

    func createReminder(
        title: String,
        notes: String?,
        calendarIdentifier: String,
        dueDate: Date?,
        alarmAt: Date?,
        priority: Int
    ) async throws -> String {
        lastCreateTitle = title
        lastCreateNotes = notes
        lastCreateCalendarId = calendarIdentifier
        lastCreateDue = dueDate
        lastCreateAlarm = alarmAt
        lastCreatePriority = priority
        defer { nextId += 1 }
        return "mock-id-\(nextId)"
    }

    func removeReminder(calendarItemIdentifier: String) async throws {}
}
