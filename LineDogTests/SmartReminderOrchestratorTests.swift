import XCTest

@testable import LineDog

@MainActor
final class SmartReminderOrchestratorTests: XCTestCase {
    private let sampleJSON = """
    {"title":"发邮件","notes":null,"target_list_name":"工作","has_alarm":true,"alarm_date":{"year":2030,"month":6,"day":10,"hour":15,"minute":30},"priority":0}
    """

    func testDecodeValidJSONWithFence() throws {
        let wrapped = "```json\n\(sampleJSON)\n```"
        let p = try LLMReminderJSONDecoderService.decode(fromModelText: wrapped)
        XCTAssertEqual(p.title, "发邮件")
        XCTAssertEqual(p.target_list_name, "工作")
        XCTAssertTrue(p.has_alarm)
        XCTAssertEqual(p.alarm_date?.hour, 15)
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
        XCTAssertTrue(r!.toastMessage.contains("发邮件"))
        XCTAssertFalse(r!.undoItemIdentifier.isEmpty)
        XCTAssertEqual(mutation.lastCreateTitle, "发邮件")
        XCTAssertNotNil(mutation.lastCreateAlarm)
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
        XCTAssertEqual(mutation.lastCreateTitle, "原始整句备忘")
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
        {"title":"T","notes":null,"target_list_name":"Inbox","has_alarm":false,"alarm_date":null,"priority":0}
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
        alarmDate: Date?,
        priority: Int
    ) async throws -> String {
        lastCreateTitle = title
        lastCreateNotes = notes
        lastCreateCalendarId = calendarIdentifier
        lastCreateAlarm = alarmDate
        lastCreatePriority = priority
        defer { nextId += 1 }
        return "mock-id-\(nextId)"
    }

    func removeReminder(calendarItemIdentifier: String) async throws {}
}
