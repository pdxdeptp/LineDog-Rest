import XCTest

@testable import MalDaze

@MainActor
final class SmartReminderOrchestratorTests: XCTestCase {
    private let sampleJSON = """
    {"title":"发邮件","is_routine":false,"notes":null,"target_list_name":"工作","has_alarm":true,"alarm_date":{"year":2030,"month":6,"day":10,"hour":15,"minute":30},"priority":0}
    """

    func testGeminiModelCatalogReadsDefaults() {
        let suiteName = "MalDaze.tests.geminiModel.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suiteName)!
        defer { d.removePersistentDomain(forName: suiteName) }
        XCTAssertEqual(MalDazeGeminiModelCatalog.modelIdForAPI(defaults: d), MalDazeDefaults.defaultGeminiModelId)
        d.set("gemini-2.5-pro", forKey: MalDazeDefaults.geminiModelId)
        XCTAssertEqual(MalDazeGeminiModelCatalog.modelIdForAPI(defaults: d), "gemini-2.5-pro")
        d.set("bad/name", forKey: MalDazeDefaults.geminiModelId)
        XCTAssertEqual(MalDazeGeminiModelCatalog.modelIdForAPI(defaults: d), MalDazeDefaults.defaultGeminiModelId)
    }

    func testSharedLLMProviderCatalogExposesSmartInputProviderDefaults() {
        XCTAssertEqual(LLMProviderCatalog.providerOptions.map(\.id.rawValue), ["gemini", "openai", "deepseek"])
        XCTAssertEqual(LLMProviderCatalog.defaultModel(for: .gemini), MalDazeDefaults.defaultGeminiModelId)
        XCTAssertEqual(LLMProviderCatalog.defaultModel(for: .openai), "gpt-5.5")
        XCTAssertEqual(LLMProviderCatalog.defaultModel(for: .deepseek), "deepseek-v4-pro")
        XCTAssertTrue(LLMProviderCatalog.models(for: .openai).contains { $0.id == "gpt-5.4-mini" })
        XCTAssertTrue(LLMProviderCatalog.models(for: .deepseek).contains { $0.id == "deepseek-v4-flash" })
    }

    func testBackendModelFallsBackToSelectedProviderDefault() {
        let suiteName = "MalDaze.tests.backendProviderFallback.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suiteName)!
        defer { d.removePersistentDomain(forName: suiteName) }

        d.set("openai", forKey: MalDazeDefaults.backendLLMProvider)
        XCTAssertEqual(MalDazeDefaults.resolvedBackendModel(defaults: d), LLMProviderCatalog.defaultModel(for: .openai))

        d.set("bad/name", forKey: MalDazeDefaults.backendLLMModel)
        XCTAssertEqual(MalDazeDefaults.resolvedBackendModel(defaults: d), LLMProviderCatalog.defaultModel(for: .openai))

        d.set("deepseek", forKey: MalDazeDefaults.backendLLMProvider)
        d.removeObject(forKey: MalDazeDefaults.backendLLMModel)
        XCTAssertEqual(MalDazeDefaults.resolvedBackendModel(defaults: d), LLMProviderCatalog.defaultModel(for: .deepseek))

        d.set("bad:model", forKey: MalDazeDefaults.backendLLMModel)
        XCTAssertEqual(MalDazeDefaults.resolvedBackendModel(defaults: d), LLMProviderCatalog.defaultModel(for: .deepseek))
    }

    func testSmartInputConfigurationFallsBackToLegacyGeminiStorage() {
        let suiteName = "MalDaze.tests.smartInputFallback.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suiteName)!
        defer { d.removePersistentDomain(forName: suiteName) }

        d.set("legacy-gemini-key", forKey: MalDazeDefaults.geminiAPIKey)
        d.set("gemini-2.5-pro", forKey: MalDazeDefaults.geminiModelId)

        XCTAssertEqual(MalDazeDefaults.resolvedSmartInputProvider(defaults: d), .gemini)
        XCTAssertEqual(MalDazeDefaults.resolvedSmartInputModel(defaults: d), "gemini-2.5-pro")
        XCTAssertEqual(MalDazeDefaults.resolvedSmartInputAPIKey(for: .gemini, defaults: d), "legacy-gemini-key")

        d.set("new-smart-gemini-key", forKey: MalDazeDefaults.smartInputGeminiAPIKey)
        d.set("gemini-2.5-flash-lite", forKey: MalDazeDefaults.smartInputLLMModel)

        XCTAssertEqual(MalDazeDefaults.resolvedSmartInputModel(defaults: d), "gemini-2.5-flash-lite")
        XCTAssertEqual(MalDazeDefaults.resolvedSmartInputAPIKey(for: .gemini, defaults: d), "new-smart-gemini-key")
    }

    func testSmartInputLegacyGeminiKeyCanBeClearedByNewSettingsStorage() {
        let suiteName = "MalDaze.tests.smartInputLegacyClear.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suiteName)!
        defer { d.removePersistentDomain(forName: suiteName) }

        d.set("legacy-gemini-key", forKey: MalDazeDefaults.geminiAPIKey)
        XCTAssertEqual(MalDazeDefaults.resolvedSmartInputAPIKey(for: .gemini, defaults: d), "legacy-gemini-key")

        d.set("", forKey: MalDazeDefaults.smartInputGeminiAPIKey)
        XCTAssertEqual(MalDazeDefaults.resolvedSmartInputAPIKey(for: .gemini, defaults: d), "")
    }

    func testAssistantAndSmartInputProviderStorageRemainIndependent() {
        let suiteName = "MalDaze.tests.independentLLM.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suiteName)!
        defer { d.removePersistentDomain(forName: suiteName) }

        d.set("openai", forKey: MalDazeDefaults.backendLLMProvider)
        d.set("gpt-5.4", forKey: MalDazeDefaults.backendLLMModel)
        d.set("assistant-openai-key", forKey: MalDazeDefaults.backendOpenAIAPIKey)
        d.set("deepseek", forKey: MalDazeDefaults.smartInputLLMProvider)
        d.set("deepseek-v4-flash", forKey: MalDazeDefaults.smartInputLLMModel)
        d.set("smart-deepseek-key", forKey: MalDazeDefaults.smartInputDeepSeekAPIKey)

        XCTAssertEqual(MalDazeDefaults.resolvedBackendAPIKey(for: .openai, defaults: d), "assistant-openai-key")
        XCTAssertEqual(MalDazeDefaults.resolvedSmartInputAPIKey(for: .deepseek, defaults: d), "smart-deepseek-key")
        XCTAssertEqual(d.string(forKey: MalDazeDefaults.backendLLMModel), "gpt-5.4")
        XCTAssertEqual(d.string(forKey: MalDazeDefaults.smartInputLLMModel), "deepseek-v4-flash")

        d.set("gemini", forKey: MalDazeDefaults.smartInputLLMProvider)
        d.set(LLMProviderCatalog.defaultModel(for: .gemini), forKey: MalDazeDefaults.smartInputLLMModel)

        XCTAssertEqual(d.string(forKey: MalDazeDefaults.backendLLMProvider), "openai")
        XCTAssertEqual(d.string(forKey: MalDazeDefaults.backendLLMModel), "gpt-5.4")
        XCTAssertEqual(MalDazeDefaults.resolvedSmartInputModel(defaults: d), MalDazeDefaults.defaultGeminiModelId)
    }

    func testSmartInputDispatchUsesSelectedProviderModelAndKeyAtRequestTime() async {
        let suiteName = "MalDaze.tests.providerDispatch.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let llm = MockReminderLLMClient()
        llm.textToReturn = sampleJSON
        let mutation = MockReminderMutationService()
        mutation.calendars = [("cal-work", "工作", true)]
        mutation.defaultCalendarId = "cal-work"

        let orch = SmartReminderOrchestrator(
            llm: llm,
            mutation: mutation,
            smartInputDefaults: defaults,
            timeZoneLabel: "America/New_York",
            cityRegionLabel: "TestCity",
            timeoutSeconds: 4.25
        )

        defaults.set("openai", forKey: MalDazeDefaults.smartInputLLMProvider)
        defaults.set("gpt-5.4-mini", forKey: MalDazeDefaults.smartInputLLMModel)
        defaults.set("smart-openai-key", forKey: MalDazeDefaults.smartInputOpenAIAPIKey)

        let r = await orch.run(rawUserInput: "明天下午三点半发邮件")
        XCTAssertEqual(r?.toastMessage, "✅ 已添加")
        XCTAssertEqual(mutation.lastCreateTitle, "发邮件")
        XCTAssertEqual(llm.calls.count, 1)
        XCTAssertEqual(llm.calls[0].provider, .openai)
        XCTAssertEqual(llm.calls[0].model, "gpt-5.4-mini")
        XCTAssertEqual(llm.calls[0].apiKey, "smart-openai-key")
        XCTAssertEqual(llm.calls[0].timeoutSeconds, 4.25)
        XCTAssertTrue(llm.calls[0].systemPrompt.contains("TestCity"))
        XCTAssertTrue(llm.calls[0].systemPrompt.contains("工作"))
        XCTAssertTrue(llm.calls[0].userText.contains("明天下午三点半发邮件"))
    }

    func testMissingSelectedProviderKeyNamesProviderAndDoesNotCallLLM() async {
        let suiteName = "MalDaze.tests.missingSelectedProviderKey.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("deepseek", forKey: MalDazeDefaults.smartInputLLMProvider)
        defaults.set("deepseek-v4-flash", forKey: MalDazeDefaults.smartInputLLMModel)

        let llm = MockReminderLLMClient()
        llm.textToReturn = sampleJSON
        let mutation = MockReminderMutationService()
        mutation.calendars = [("cal1", "Inbox", true)]
        mutation.defaultCalendarId = "cal1"

        let orch = SmartReminderOrchestrator(
            llm: llm,
            mutation: mutation,
            smartInputDefaults: defaults,
            timeZoneLabel: "UTC",
            cityRegionLabel: "X"
        )

        let r = await orch.run(rawUserInput: "原始整句备忘")
        XCTAssertEqual(r?.toastMessage, "⚡️ 请先在设置中填写 DeepSeek API Key")
        XCTAssertTrue(llm.calls.isEmpty)
        XCTAssertNil(mutation.lastCreateTitle)
    }

    func testLegacyGeminiSmartInputSettingsStillDispatch() async {
        let suiteName = "MalDaze.tests.legacyGeminiDispatch.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("legacy-gemini-key", forKey: MalDazeDefaults.geminiAPIKey)
        defaults.set("gemini-2.5-pro", forKey: MalDazeDefaults.geminiModelId)

        let llm = MockReminderLLMClient()
        llm.textToReturn = sampleJSON
        let mutation = MockReminderMutationService()
        mutation.calendars = [("cal-work", "工作", true)]
        mutation.defaultCalendarId = "cal-work"

        let orch = SmartReminderOrchestrator(
            llm: llm,
            mutation: mutation,
            smartInputDefaults: defaults,
            timeZoneLabel: "UTC",
            cityRegionLabel: "X"
        )

        let r = await orch.run(rawUserInput: "明天下午三点半发邮件")
        XCTAssertEqual(r?.toastMessage, "✅ 已添加")
        XCTAssertEqual(mutation.lastCreateTitle, "发邮件")
        XCTAssertEqual(llm.calls.count, 1)
        XCTAssertEqual(llm.calls[0].provider, .gemini)
        XCTAssertEqual(llm.calls[0].model, "gemini-2.5-pro")
        XCTAssertEqual(llm.calls[0].apiKey, "legacy-gemini-key")
    }

    func testOpenAICompatibleClientPreservesArrayJSONContractInRequest() async throws {
        let expectedText = #"[{"title":"任务甲"},{"title":"任务乙"}]"#
        try configureSmartReminderHTTPStub(jsonObject: [
            "choices": [
                [
                    "message": [
                        "content": expectedText
                    ]
                ]
            ]
        ])
        let client = ReminderLLMAPIClient(urlSessionConfiguration: smartReminderStubConfiguration())

        let result = try await client.generateStructuredReminderJSON(
            provider: .openai,
            model: "gpt-5.4-mini",
            systemPrompt: "Return reminder JSON.",
            userText: "明天提醒我两件事",
            apiKey: "openai-test-key",
            timeoutSeconds: 1
        )

        let request = try XCTUnwrap(SmartReminderURLProtocolStub.lastRequest)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://api.openai.com/v1/chat/completions")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer openai-test-key")

        let bodyData = try XCTUnwrap(request.httpBodyStreamData)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        XCTAssertEqual(payload["model"] as? String, "gpt-5.4-mini")
        XCTAssertEqual(payload["temperature"] as? Double, 0.2)
        XCTAssertNil(payload["response_format"])

        let messages = try XCTUnwrap(payload["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0]["role"] as? String, "system")
        XCTAssertEqual(messages[0]["content"] as? String, "Return reminder JSON.")
        XCTAssertEqual(messages[1]["role"] as? String, "user")
        XCTAssertEqual(messages[1]["content"] as? String, "明天提醒我两件事")
        XCTAssertEqual(result, expectedText)
    }

    func testGeminiClientUsesExplicitModelAndParsesCandidateText() async throws {
        let expectedText = #"{"title":"买牛奶"}"#
        try configureSmartReminderHTTPStub(jsonObject: [
            "candidates": [
                [
                    "content": [
                        "parts": [
                            [
                                "text": expectedText
                            ]
                        ]
                    ]
                ]
            ]
        ])
        let client = ReminderLLMAPIClient(urlSessionConfiguration: smartReminderStubConfiguration())

        let result = try await client.generateStructuredReminderJSON(
            provider: .gemini,
            model: "gemini-explicit-model",
            systemPrompt: "System prompt",
            userText: "买牛奶",
            apiKey: "gemini-test-key",
            timeoutSeconds: 1
        )

        let request = try XCTUnwrap(SmartReminderURLProtocolStub.lastRequest)
        let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
        let queryItems = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) })
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(components.path, "/v1beta/models/gemini-explicit-model:generateContent")
        XCTAssertEqual(queryItems["key"], "gemini-test-key")

        let bodyData = try XCTUnwrap(request.httpBodyStreamData)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        XCTAssertNotNil(payload["systemInstruction"])
        XCTAssertNotNil(payload["contents"])
        let generationConfig = try XCTUnwrap(payload["generationConfig"] as? [String: Any])
        XCTAssertEqual(generationConfig["responseMimeType"] as? String, "application/json")
        XCTAssertEqual(result, expectedText)
    }

    func testReminderLLMHTTPStatusLocalizedDescriptionIncludesStatusWithoutKey() async throws {
        try configureSmartReminderHTTPStub(jsonObject: ["error": "rate limited"], statusCode: 429)
        let client = ReminderLLMAPIClient(urlSessionConfiguration: smartReminderStubConfiguration())

        do {
            _ = try await client.generateStructuredReminderJSON(
                provider: .openai,
                model: "gpt-5.4-mini",
                systemPrompt: "System prompt",
                userText: "Text",
                apiKey: "secret-key-should-not-leak",
                timeoutSeconds: 1
            )
            XCTFail("Expected HTTP status error")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("429"))
            XCTAssertFalse(error.localizedDescription.contains("secret-key-should-not-leak"))
        }
    }

    func testReminderLLMErrorDescriptionsAreProviderSafe() {
        XCTAssertTrue(GeminiRemindersAPIError.invalidURL.localizedDescription.contains("Invalid Gemini request URL"))
        XCTAssertTrue(GeminiRemindersAPIError.emptyResponse.localizedDescription.contains("Gemini returned an empty response"))
        XCTAssertTrue(GeminiRemindersAPIError.noCandidates.localizedDescription.contains("Gemini response did not include candidate text"))
        XCTAssertTrue(GeminiRemindersAPIError.httpStatus(503).localizedDescription.contains("503"))

        XCTAssertTrue(ReminderLLMAPIError.invalidURL.localizedDescription.contains("Invalid reminder LLM request URL"))
        XCTAssertTrue(ReminderLLMAPIError.emptyResponse.localizedDescription.contains("reminder LLM provider returned an empty response"))
        XCTAssertTrue(ReminderLLMAPIError.noChoices.localizedDescription.contains("reminder LLM provider response did not include message text"))
        XCTAssertTrue(ReminderLLMAPIError.httpStatus(429).localizedDescription.contains("429"))
    }

    func testDecodePayloadsFromJSONArray() throws {
        let json = """
        [{"title":"开chalse shwab","is_routine":false,"notes":null,"target_list_name":"Reminders","has_alarm":false,"alarm_date":{"year":2026,"month":3,"day":27,"hour":10,"minute":0},"priority":0},{"title":"去百合食品买零食","is_routine":false,"notes":null,"target_list_name":"Reminders","has_alarm":false,"alarm_date":{"year":2026,"month":3,"day":27,"hour":10,"minute":0},"priority":0}]
        """
        let list = try LLMReminderJSONDecoderService.decodePayloads(fromModelText: json)
        XCTAssertEqual(list.count, 2)
        XCTAssertEqual(list[0].title, "开chalse shwab")
        XCTAssertEqual(list[1].title, "去百合食品买零食")
    }

    func testDecodeSingleObjectRejectsDecodeWhenMultipleInArray() throws {
        let json = """
        [{"title":"a","is_routine":false,"notes":null,"target_list_name":"Reminders","has_alarm":false,"priority":0},{"title":"b","is_routine":false,"notes":null,"target_list_name":"Reminders","has_alarm":false,"priority":0}]
        """
        XCTAssertThrowsError(try LLMReminderJSONDecoderService.decode(fromModelText: json)) { err in
            XCTAssertEqual(err as? SmartReminderParseError, .expectedSinglePayload)
        }
    }

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

    func testDecodeWeeklyRecurrenceSnakeCase() throws {
        let json = """
        {"title":"作业","is_routine":false,"notes":null,"target_list_name":"Reminders","has_alarm":false,"alarm_date":{"year":2026,"month":3,"day":23,"hour":23,"minute":59},"priority":0,"recurrence":{"frequency":"weekly","interval":1,"days_of_week":[1]}}
        """
        let p = try LLMReminderJSONDecoderService.decode(fromModelText: json)
        XCTAssertEqual(p.recurrence?.frequency, "weekly")
        XCTAssertEqual(p.recurrence?.interval, 1)
        XCTAssertEqual(p.recurrence?.days_of_week, [1])
        XCTAssertNil(p.recurrence?.day_of_month)
    }

    func testDecodeRecurrenceCamelCaseDaysOfWeek() throws {
        let json = """
        {"title":"x","is_routine":false,"notes":null,"target_list_name":"Reminders","has_alarm":false,"priority":0,"recurrence":{"frequency":"weekly","daysOfWeek":[2,3]}}
        """
        let p = try LLMReminderJSONDecoderService.decode(fromModelText: json)
        XCTAssertEqual(p.recurrence?.days_of_week, [2, 3])
    }

    func testOrchestratorPassesWeeklyRecurrenceToMutation() async {
        let gemini = MockGeminiRemindersClient()
        gemini.textToReturn = """
        {"title":"621 reflection","is_routine":false,"notes":"一次两个","target_list_name":"Reminders","has_alarm":false,"alarm_date":{"year":2026,"month":3,"day":23,"hour":23,"minute":59},"priority":0,"recurrence":{"frequency":"weekly","interval":1,"days_of_week":[1]}}
        """
        let mutation = MockReminderMutationService()
        mutation.calendars = [("cal-r", "Reminders", true)]
        mutation.defaultCalendarId = "cal-r"

        let orch = SmartReminderOrchestrator(
            gemini: gemini,
            mutation: mutation,
            apiKeyProvider: { "k" },
            timeZoneLabel: "America/New_York",
            cityRegionLabel: "X"
        )

        let r = await orch.run(rawUserInput: "每周日晚上前做 reading")
        XCTAssertNotNil(r)
        XCTAssertTrue(r!.toastMessage.contains("（重复）"))
        XCTAssertEqual(mutation.lastRecurrence?.frequency, .weekly)
        XCTAssertEqual(mutation.lastRecurrence?.daysOfTheWeek, [1])
    }

    func testOrchestratorSavesMultipleRemindersWhenModelReturnsJSONArray() async {
        let gemini = MockGeminiRemindersClient()
        gemini.textToReturn = """
        [{"title":"任务甲","is_routine":false,"notes":null,"target_list_name":"Reminders","has_alarm":false,"alarm_date":{"year":2026,"month":3,"day":27,"hour":10,"minute":0},"priority":0},{"title":"任务乙","is_routine":false,"notes":null,"target_list_name":"Reminders","has_alarm":false,"alarm_date":{"year":2026,"month":3,"day":27,"hour":11,"minute":0},"priority":0}]
        """
        let mutation = MockReminderMutationService()
        mutation.calendars = [("cal-r", "Reminders", true)]
        mutation.defaultCalendarId = "cal-r"

        let orch = SmartReminderOrchestrator(
            gemini: gemini,
            mutation: mutation,
            apiKeyProvider: { "k" },
            timeZoneLabel: "America/New_York",
            cityRegionLabel: "X"
        )

        let r = await orch.run(rawUserInput: "下周五两件事")
        XCTAssertNotNil(r)
        XCTAssertFalse(r!.wasFallback)
        XCTAssertTrue(r!.toastMessage.contains("2 项"))
        XCTAssertEqual(r!.undoItemIdentifiers.count, 2)
        XCTAssertEqual(mutation.createdTitles, ["任务甲", "任务乙"])
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
        XCTAssertNil(mutation.lastRecurrence)
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

    func testEmptyApiKeyShowsErrorAndDoesNotCreateReminder() async {
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
        XCTAssertFalse(r!.wasFallback)
        XCTAssertEqual(r!.toastMessage, "⚡️ 请先在设置中填写 Gemini API Key")
        XCTAssertNil(mutation.lastCreateTitle)
    }

    func testGeminiFailureShowsErrorAndDoesNotCreateReminder() async {
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
        XCTAssertFalse(r!.wasFallback)
        XCTAssertNil(mutation.lastCreateTitle)
        XCTAssertTrue(r!.toastMessage.hasPrefix("⚡️ 智能提醒请求失败："))
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

        _ = await orch.run(rawUserInput: "帮我放进收件箱")
        XCTAssertEqual(mutation.lastCreateCalendarId, "def")
    }

    func testDecodeAlarmDateNullHourMinuteIsUnspecifiedPlaceholder() throws {
        let json = """
        {"title":"Seminar","is_routine":false,"notes":null,"target_list_name":"Reminders","has_alarm":false,"alarm_date":{"year":2026,"month":3,"day":30,"hour":null,"minute":null},"priority":0}
        """
        let p = try LLMReminderJSONDecoderService.decode(fromModelText: json)
        XCTAssertTrue(p.alarm_date?.isTimeUnspecified == true)
        XCTAssertEqual(p.alarm_date?.hour, 12)
        XCTAssertEqual(p.alarm_date?.minute, 0)
    }

    func testWithInferredAlarmWallClockUsesTaskContent() throws {
        let json = """
        {"title":"Seminar","is_routine":false,"notes":null,"target_list_name":"Reminders","has_alarm":false,"alarm_date":{"year":2026,"month":3,"day":30,"hour":null,"minute":null},"priority":0}
        """
        let p = try LLMReminderJSONDecoderService.decode(fromModelText: json)
        let refined = p.withInferredAlarmWallClock(rawUserInput: "")
        XCTAssertEqual(refined.alarm_date?.isTimeUnspecified, false)
        XCTAssertEqual(refined.alarm_date?.hour, 10)
        XCTAssertEqual(refined.alarm_date?.minute, 0)
    }

    func testDecodeOmittedTargetListDefaultsToReminders() throws {
        let json = """
        {"title":"x","is_routine":false,"notes":null,"has_alarm":false,"priority":0}
        """
        let p = try LLMReminderJSONDecoderService.decode(fromModelText: json)
        XCTAssertEqual(p.target_list_name, "Reminders")
    }

    func testParsedPayloadSaveFailureDoesNotFallbackToRawTitle() async {
        let gemini = MockGeminiRemindersClient()
        gemini.textToReturn = sampleJSON
        let mutation = MockReminderMutationService()
        mutation.calendars = [("cal-work", "工作", true)]
        mutation.defaultCalendarId = "cal-work"
        mutation.createReminderError = NSError(domain: "test", code: 1)

        let orch = SmartReminderOrchestrator(
            gemini: gemini,
            mutation: mutation,
            apiKeyProvider: { "k" },
            timeZoneLabel: "UTC",
            cityRegionLabel: "X"
        )

        let raw = "明天下午三点半发邮件"
        let r = await orch.run(rawUserInput: raw)
        XCTAssertNotNil(r)
        XCTAssertTrue(r!.toastMessage.contains("未能保存"))
        XCTAssertTrue(r!.undoItemIdentifier.isEmpty)
        XCTAssertNil(mutation.lastCreateTitle)
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

private final class MockReminderLLMClient: ReminderLLMGenerating, @unchecked Sendable {
    struct Call {
        let provider: LLMProviderID
        let model: String
        let systemPrompt: String
        let userText: String
        let apiKey: String
        let timeoutSeconds: TimeInterval
    }

    var textToReturn: String?
    var shouldThrow = false
    private(set) var calls: [Call] = []

    func generateStructuredReminderJSON(
        provider: LLMProviderID,
        model: String,
        systemPrompt: String,
        userText: String,
        apiKey: String,
        timeoutSeconds: TimeInterval
    ) async throws -> String {
        calls.append(Call(
            provider: provider,
            model: model,
            systemPrompt: systemPrompt,
            userText: userText,
            apiKey: apiKey,
            timeoutSeconds: timeoutSeconds
        ))
        if shouldThrow { throw URLError(.timedOut) }
        return textToReturn ?? ""
    }
}

private final class MockReminderMutationService: ReminderMutationServing {
    var calendars: [(String, String, Bool)] = []
    var defaultCalendarId: String?
    private(set) var createdTitles: [String] = []
    private(set) var lastCreateTitle: String?
    private(set) var lastCreateNotes: String?
    private(set) var lastCreateCalendarId: String?
    private(set) var lastCreateDue: Date?
    private(set) var lastCreateAlarm: Date?
    private(set) var lastCreatePriority: Int?
    private(set) var lastRecurrence: ReminderRecurrenceSpec?
    /// 非 nil 时 `createReminder` 抛错（模拟 EventKit 保存失败）。
    var createReminderError: Error?
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
        priority: Int,
        recurrence: ReminderRecurrenceSpec?
    ) async throws -> String {
        if let createReminderError {
            throw createReminderError
        }
        createdTitles.append(title)
        lastCreateTitle = title
        lastCreateNotes = notes
        lastCreateCalendarId = calendarIdentifier
        lastCreateDue = dueDate
        lastCreateAlarm = alarmAt
        lastCreatePriority = priority
        lastRecurrence = recurrence
        defer { nextId += 1 }
        return "mock-id-\(nextId)"
    }

    func removeReminder(calendarItemIdentifier: String) async throws {}
}

private final class SmartReminderURLProtocolStub: URLProtocol {
    nonisolated(unsafe) static var responseData = Data()
    nonisolated(unsafe) static var statusCode = 200
    nonisolated(unsafe) static var lastRequest: URLRequest?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lastRequest = request
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: Self.statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private func configureSmartReminderHTTPStub(jsonObject: [String: Any], statusCode: Int = 200) throws {
    SmartReminderURLProtocolStub.responseData = try JSONSerialization.data(withJSONObject: jsonObject)
    SmartReminderURLProtocolStub.statusCode = statusCode
    SmartReminderURLProtocolStub.lastRequest = nil
}

private func smartReminderStubConfiguration() -> URLSessionConfiguration {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [SmartReminderURLProtocolStub.self]
    return configuration
}

private extension URLRequest {
    var httpBodyStreamData: Data? {
        guard let stream = httpBodyStream else { return httpBody }
        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
