import XCTest
@testable import MalDaze

@MainActor
final class NutritionTodayViewModelTests: XCTestCase {
    func testFreshRecommendationSuppliesLoggableItemsAndIgnoresLegacyPanelSuggestions() async throws {
        let reader = StubNutritionReader()
        let recommendationReader = StubRecommendationReader(snapshot: .available())
        let cli = MockNutritionCLI()
        let vm = NutritionTodayViewModel(reader: reader, recommendationReader: recommendationReader, cli: cli)

        vm.loadToday()
        XCTAssertEqual(vm.recommendationState, .fresh(StubRecommendationReader.availableSnapshot))
        XCTAssertEqual(vm.loggableItems.count, 1)
        XCTAssertEqual(vm.loggableItems[0].flatIndex, 1)
        XCTAssertEqual(vm.loggableItems[0].displayName, "去脂希腊酸奶 250g")
        XCTAssertEqual(vm.loggableItems[0].name, "希腊酸奶·去脂")

        await vm.logItem(flatIndex: 1)
        XCTAssertEqual(cli.lastName, "希腊酸奶·去脂")
        XCTAssertEqual(cli.lastGrams, 250)
        XCTAssertFalse(vm.isLogging)
    }

    func testSuccessfulLogReloadsFactsAndLeavesRecommendationStale() async {
        let reader = ReloadingStubNutritionReader()
        let recommendationReader = StubRecommendationReader(snapshot: .available())
        let cli = MockNutritionCLI()
        let vm = NutritionTodayViewModel(reader: reader, recommendationReader: recommendationReader, cli: cli)

        vm.loadToday()
        XCTAssertEqual(vm.loggableItems.count, 1)
        XCTAssertEqual(vm.recommendationState, .fresh(StubRecommendationReader.availableSnapshot))

        await vm.logItem(flatIndex: 1)

        XCTAssertEqual(cli.logCount, 1)
        XCTAssertEqual(reader.readCount, 2)
        XCTAssertEqual(vm.loggableItems.count, 0)
        XCTAssertEqual(vm.recommendationState, .stale(StubRecommendationReader.availableSnapshot))
        if case .loaded(let log) = vm.loadState {
            XCTAssertEqual(log.records.count, 1)
            XCTAssertEqual(log.panel?.updatedAt, "2099-01-01T08:10:00+08:00")
        } else {
            XCTFail("expected loaded after reload")
        }
    }

    func testIsLoggingBlocksSecondLog() async {
        let reader = StubNutritionReader()
        let recommendationReader = StubRecommendationReader(snapshot: .available())
        let cli = SlowMockNutritionCLI()
        let vm = NutritionTodayViewModel(reader: reader, recommendationReader: recommendationReader, cli: cli)

        vm.loadToday()
        let first = Task { await vm.logItem(flatIndex: 1) }
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(vm.isLogging)

        await vm.logItem(flatIndex: 1)
        await first.value

        XCTAssertEqual(cli.logCount, 1)
        XCTAssertEqual(cli.lastName, "希腊酸奶·去脂")
    }

    func testMoreThanNineFreshRecommendationItemsOnlyFirstNineHaveShortcutRange() {
        let items = NutritionLoggableItem.flattened(from: .manyLoggableItems(count: 10))
        XCTAssertEqual(items.count, 10)
        XCTAssertEqual(items[8].flatIndex, 9)
        XCTAssertEqual(items[9].flatIndex, 10)
    }

    func testDuplicateLoggableRecommendationItemsKeepDistinctFlatIndexMapping() {
        let snapshot = NutritionRecommendationSnapshot.duplicateLoggableItems()
        let reader = StubNutritionReader()
        let recommendationReader = StubRecommendationReader(snapshot: snapshot)
        let vm = NutritionTodayViewModel(reader: reader, recommendationReader: recommendationReader, cli: MockNutritionCLI())

        vm.loadToday()

        XCTAssertEqual(vm.loggableItems.map(\.flatIndex), [1, 2])
        XCTAssertEqual(vm.loggableItems.map(\.sourceItemID), snapshot.suggestions[0].items.map(\.id))
        XCTAssertNotEqual(vm.loggableItems[0].sourceItemID, vm.loggableItems[1].sourceItemID)
    }

    func testStaleRecommendationDisablesActions() {
        let reader = StubNutritionReader()
        let recommendationReader = StubRecommendationReader(snapshot: .stale())
        let vm = NutritionTodayViewModel(reader: reader, recommendationReader: recommendationReader, cli: MockNutritionCLI())

        vm.loadToday()

        XCTAssertEqual(vm.recommendationState, .stale(StubRecommendationReader.staleSnapshot))
        XCTAssertTrue(vm.loggableItems.isEmpty)
        XCTAssertFalse(vm.canUseDigitShortcuts)
        XCTAssertEqual(vm.recommendationMessage, "Hermes 建议已过期，等待新的饮食建议。")
    }

    func testPollingReloadsWhenRecommendationAppearsOrGeneratedAtChangesWithoutPanelUpdate() {
        let reader = CountingStableNutritionReader()
        let recommendationReader = MutableRecommendationReader(result: .failure(.fileNotFound))
        let vm = NutritionTodayViewModel(reader: reader, recommendationReader: recommendationReader, cli: MockNutritionCLI())

        vm.loadToday()
        XCTAssertEqual(vm.recommendationState, .missing)
        XCTAssertTrue(vm.loggableItems.isEmpty)

        let firstSnapshot = NutritionRecommendationSnapshot.available()
        recommendationReader.result = .success(firstSnapshot)
        vm.pollForExternalUpdates()

        XCTAssertEqual(vm.recommendationState, .fresh(firstSnapshot))
        XCTAssertEqual(vm.loggableItems.map(\.name), ["希腊酸奶·去脂"])
        XCTAssertEqual(reader.readCount, 3)

        let updatedSnapshot = firstSnapshot.replacing(generatedAt: "2099-01-01T08:07:00+08:00")
        recommendationReader.result = .success(updatedSnapshot)
        vm.pollForExternalUpdates()

        XCTAssertEqual(vm.recommendationState, .fresh(updatedSnapshot))
        XCTAssertEqual(vm.loggableItems.map(\.name), ["希腊酸奶·去脂"])
        XCTAssertEqual(reader.readCount, 5)
    }

    func testUnavailableRecommendationWithOldBasisIsStaleAndDisablesActions() {
        let oldDate = NutritionRecommendationSnapshot.unavailable(date: "2098-12-31")
        let oldDateVM = NutritionTodayViewModel(
            reader: StubNutritionReader(),
            recommendationReader: StubRecommendationReader(snapshot: oldDate),
            cli: MockNutritionCLI()
        )
        oldDateVM.loadToday()
        XCTAssertEqual(oldDateVM.recommendationState, .stale(oldDate))
        XCTAssertTrue(oldDateVM.loggableItems.isEmpty)
        XCTAssertFalse(oldDateVM.canUseDigitShortcuts)

        let oldPanelUpdatedAt = NutritionRecommendationSnapshot.unavailable(
            dailyLogPanelUpdatedAt: "2099-01-01T07:30:00+08:00"
        )
        let oldPanelVM = NutritionTodayViewModel(
            reader: StubNutritionReader(),
            recommendationReader: StubRecommendationReader(snapshot: oldPanelUpdatedAt),
            cli: MockNutritionCLI()
        )
        oldPanelVM.loadToday()
        XCTAssertEqual(oldPanelVM.recommendationState, .stale(oldPanelUpdatedAt))
        XCTAssertTrue(oldPanelVM.loggableItems.isEmpty)
        XCTAssertFalse(oldPanelVM.canUseDigitShortcuts)
        XCTAssertEqual(oldPanelVM.recommendationMessage, "Hermes 建议已过期，等待新的饮食建议。")
    }

    func testMissingUnavailableAndInvalidRecommendationStatesDisableActions() {
        let missingVM = NutritionTodayViewModel(
            reader: StubNutritionReader(),
            recommendationReader: ThrowingRecommendationReader(error: .fileNotFound),
            cli: MockNutritionCLI()
        )
        missingVM.loadToday()
        XCTAssertEqual(missingVM.recommendationState, .missing)
        XCTAssertEqual(missingVM.recommendationMessage, "等待 Hermes 写入饮食建议。")
        XCTAssertTrue(missingVM.loggableItems.isEmpty)

        let unavailable = StubRecommendationReader.unavailableSnapshot
        let unavailableVM = NutritionTodayViewModel(
            reader: StubNutritionReader(),
            recommendationReader: StubRecommendationReader(snapshot: unavailable),
            cli: MockNutritionCLI()
        )
        unavailableVM.loadToday()
        XCTAssertEqual(unavailableVM.recommendationState, .unavailable(unavailable))
        XCTAssertEqual(unavailableVM.recommendationMessage, "Hermes 暂时无法给出饮食建议。")
        XCTAssertTrue(unavailableVM.loggableItems.isEmpty)

        let invalidVM = NutritionTodayViewModel(
            reader: StubNutritionReader(),
            recommendationReader: ThrowingRecommendationReader(error: .invalidJSON),
            cli: MockNutritionCLI()
        )
        invalidVM.loadToday()
        XCTAssertEqual(invalidVM.recommendationState, .invalid("recommendation.json 格式无效。"))
        XCTAssertEqual(invalidVM.recommendationMessage, "recommendation.json 格式无效。")
        XCTAssertTrue(invalidVM.loggableItems.isEmpty)
    }
}

private final class CountingStableNutritionReader: NutritionDailyLogReading {
    let fileURL = URL(fileURLWithPath: "/tmp/unused.json")
    private(set) var readCount = 0

    func read() throws -> NutritionDailyLog {
        readCount += 1
        return StubNutritionReader.makeLog(suggestions: StubNutritionReader.twoItemSuggestions())
    }
}

private final class ReloadingStubNutritionReader: NutritionDailyLogReading {
    let fileURL = URL(fileURLWithPath: "/tmp/unused.json")
    var readCount = 0

    func read() throws -> NutritionDailyLog {
        readCount += 1
        if readCount == 1 {
            return StubNutritionReader.makeLog(suggestions: StubNutritionReader.twoItemSuggestions())
        }
        return StubNutritionReader.makeLog(
            suggestions: [],
            records: [
                NutritionDailyRecord(name: "希腊酸奶·去脂", kcal: 150, proteinG: 25, carbsG: 8, fatG: 0, sodiumMg: 90, weightG: 250),
            ],
            panelUpdatedAt: "2099-01-01T08:10:00+08:00"
        )
    }
}

private struct StubNutritionReader: NutritionDailyLogReading {
    let fileURL = URL(fileURLWithPath: "/tmp/unused.json")

    func read() throws -> NutritionDailyLog {
        Self.makeLog(suggestions: Self.twoItemSuggestions())
    }

    static func twoItemSuggestions() -> [NutritionPanelSuggestion] {
        [
            NutritionPanelSuggestion(
                label: "建议",
                items: [
                    NutritionPanelSuggestionItem(name: "燕麦", grams: 40, kcal: 150, proteinG: 5, carbsG: 26, fatG: 2, sodiumMg: 0),
                    NutritionPanelSuggestionItem(name: "蓝莓", grams: 80, kcal: 46, proteinG: 1, carbsG: 11, fatG: 0, sodiumMg: 1),
                ],
                total: nil,
                withinSlack: true
            ),
        ]
    }

    static func makeLog(
        suggestions: [NutritionPanelSuggestion],
        records: [NutritionDailyRecord] = [],
        panelUpdatedAt: String = "2099-01-01T08:00:00+08:00"
    ) -> NutritionDailyLog {
        let panel = NutritionPanel(
            schemaVersion: 1,
            updatedAt: panelUpdatedAt,
            dayLabel: "休息日",
            targets: NutritionMacroBucket(kcal: 1800, proteinG: 120, carbsG: 180, fatG: 60, sodiumMg: 2300),
            consumed: NutritionMacroBucket(kcal: 0, proteinG: 0, carbsG: 0, fatG: 0, sodiumMg: 0),
            remaining: NutritionMacroBucket(kcal: 1800, proteinG: 120, carbsG: 180, fatG: 60, sodiumMg: 2300),
            suggestions: suggestions,
            calorieSlack: 50
        )
        return NutritionDailyLog(date: "2099-01-01", dayType: "rest", records: records, panel: panel)
    }
}

private struct StubRecommendationReader: NutritionRecommendationReading {
    static let availableSnapshot = NutritionRecommendationSnapshot.available()
    static let staleSnapshot = NutritionRecommendationSnapshot.stale()
    static let unavailableSnapshot = NutritionRecommendationSnapshot.unavailable()

    let fileURL = URL(fileURLWithPath: "/tmp/recommendation.json")
    let snapshot: NutritionRecommendationSnapshot

    func read() throws -> NutritionRecommendationSnapshot {
        snapshot
    }
}

private struct ThrowingRecommendationReader: NutritionRecommendationReading {
    let fileURL = URL(fileURLWithPath: "/tmp/recommendation.json")
    let error: NutritionRecommendationContractError

    func read() throws -> NutritionRecommendationSnapshot {
        throw error
    }
}

private final class MutableRecommendationReader: NutritionRecommendationReading {
    let fileURL = URL(fileURLWithPath: "/tmp/recommendation.json")
    var result: Result<NutritionRecommendationSnapshot, NutritionRecommendationContractError>

    init(result: Result<NutritionRecommendationSnapshot, NutritionRecommendationContractError>) {
        self.result = result
    }

    func read() throws -> NutritionRecommendationSnapshot {
        try result.get()
    }
}

private extension NutritionRecommendationSnapshot {
    static func available() -> NutritionRecommendationSnapshot {
        NutritionRecommendationSnapshot(
            schemaVersion: 1,
            date: "2099-01-01",
            generatedAt: "2099-01-01T08:05:00+08:00",
            source: NutritionRecommendationSource(kind: "morning_briefing", channel: "feishu"),
            basedOn: NutritionRecommendationBasis(
                dailyLogDate: "2099-01-01",
                dailyLogPanelUpdatedAt: "2099-01-01T08:00:00+08:00",
                recordsCount: 0
            ),
            state: .available,
            summary: "今天还需要补蛋白和一点碳水，脂肪空间不多。",
            suggestions: [
                NutritionRecommendationSuggestion(
                    label: "现在最合适",
                    rationale: "补蛋白，热量温和。",
                    items: [
                        NutritionRecommendationItem(
                            displayName: "去脂希腊酸奶 250g",
                            name: "希腊酸奶·去脂",
                            grams: 250,
                            loggable: true
                        ),
                        NutritionRecommendationItem(
                            displayName: "再喝一杯水",
                            name: nil,
                            grams: nil,
                            loggable: false
                        ),
                    ],
                    warnings: ["脂肪空间不多"]
                ),
            ]
        )
    }

    static func stale() -> NutritionRecommendationSnapshot {
        var snapshot = available()
        snapshot = NutritionRecommendationSnapshot(
            schemaVersion: snapshot.schemaVersion,
            date: snapshot.date,
            generatedAt: snapshot.generatedAt,
            source: snapshot.source,
            basedOn: NutritionRecommendationBasis(
                dailyLogDate: snapshot.basedOn.dailyLogDate,
                dailyLogPanelUpdatedAt: "2099-01-01T07:30:00+08:00",
                recordsCount: snapshot.basedOn.recordsCount
            ),
            state: snapshot.state,
            summary: snapshot.summary,
            suggestions: snapshot.suggestions
        )
        return snapshot
    }

    static func unavailable() -> NutritionRecommendationSnapshot {
        let snapshot = available()
        return NutritionRecommendationSnapshot(
            schemaVersion: snapshot.schemaVersion,
            date: snapshot.date,
            generatedAt: snapshot.generatedAt,
            source: snapshot.source,
            basedOn: snapshot.basedOn,
            state: .unavailable,
            summary: "Hermes 暂时无法给出饮食建议。",
            suggestions: []
        )
    }

    static func unavailable(
        date: String = "2099-01-01",
        dailyLogPanelUpdatedAt: String = "2099-01-01T08:00:00+08:00"
    ) -> NutritionRecommendationSnapshot {
        let snapshot = available()
        return NutritionRecommendationSnapshot(
            schemaVersion: snapshot.schemaVersion,
            date: date,
            generatedAt: snapshot.generatedAt,
            source: snapshot.source,
            basedOn: NutritionRecommendationBasis(
                dailyLogDate: date,
                dailyLogPanelUpdatedAt: dailyLogPanelUpdatedAt,
                recordsCount: snapshot.basedOn.recordsCount
            ),
            state: .unavailable,
            summary: "Hermes 暂时无法给出饮食建议。",
            suggestions: []
        )
    }

    static func duplicateLoggableItems() -> NutritionRecommendationSnapshot {
        let snapshot = available()
        return NutritionRecommendationSnapshot(
            schemaVersion: snapshot.schemaVersion,
            date: snapshot.date,
            generatedAt: snapshot.generatedAt,
            source: snapshot.source,
            basedOn: snapshot.basedOn,
            state: snapshot.state,
            summary: snapshot.summary,
            suggestions: [
                NutritionRecommendationSuggestion(
                    label: "菜单",
                    rationale: nil,
                    items: [
                        NutritionRecommendationItem(
                            displayName: "去脂希腊酸奶 250g",
                            name: "希腊酸奶·去脂",
                            grams: 250,
                            loggable: true
                        ),
                        NutritionRecommendationItem(
                            displayName: "去脂希腊酸奶 250g",
                            name: "希腊酸奶·去脂",
                            grams: 250,
                            loggable: true
                        ),
                    ],
                    warnings: []
                ),
            ]
        )
    }

    static func manyLoggableItems(count: Int) -> NutritionRecommendationSnapshot {
        let snapshot = available()
        return NutritionRecommendationSnapshot(
            schemaVersion: snapshot.schemaVersion,
            date: snapshot.date,
            generatedAt: snapshot.generatedAt,
            source: snapshot.source,
            basedOn: snapshot.basedOn,
            state: snapshot.state,
            summary: snapshot.summary,
            suggestions: [
                NutritionRecommendationSuggestion(
                    label: "菜单",
                    rationale: nil,
                    items: (1...count).map {
                        NutritionRecommendationItem(
                            displayName: "食物\($0) \($0 * 10)g",
                            name: "食物\($0)",
                            grams: Double($0 * 10),
                            loggable: true
                        )
                    },
                    warnings: []
                ),
            ]
        )
    }

    func replacing(generatedAt: String) -> NutritionRecommendationSnapshot {
        NutritionRecommendationSnapshot(
            schemaVersion: schemaVersion,
            date: date,
            generatedAt: generatedAt,
            source: source,
            basedOn: basedOn,
            state: state,
            summary: summary,
            suggestions: suggestions
        )
    }
}

private final class MockNutritionCLI: NutritionHermesCLI {
    var lastName: String?
    var lastGrams: Double?
    var logCount = 0

    func logFood(name: String, grams: Double) async throws {
        logCount += 1
        lastName = name
        lastGrams = grams
    }
}

private final class SlowMockNutritionCLI: NutritionHermesCLI {
    var lastName: String?
    var logCount = 0

    func logFood(name: String, grams: Double) async throws {
        logCount += 1
        lastName = name
        try await Task.sleep(nanoseconds: 200_000_000)
    }
}
