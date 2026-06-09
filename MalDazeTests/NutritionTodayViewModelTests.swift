import XCTest
@testable import MalDaze

@MainActor
final class NutritionTodayViewModelTests: XCTestCase {
    func testFlattenedMappingAndLogItem() async throws {
        let reader = StubNutritionReader()
        let cli = MockNutritionCLI()
        let vm = NutritionTodayViewModel(reader: reader, cli: cli)

        vm.loadToday()
        XCTAssertEqual(vm.loggableItems.count, 2)
        XCTAssertEqual(vm.loggableItems[1].flatIndex, 2)
        XCTAssertEqual(vm.loggableItems[1].name, "蓝莓")

        await vm.logItem(flatIndex: 2)
        XCTAssertEqual(cli.lastName, "蓝莓")
        XCTAssertEqual(cli.lastGrams, 80)
        XCTAssertFalse(vm.isLogging)
    }

    func testSuccessfulLogReloadsPanelWithoutLoadingFlash() async {
        let reader = ReloadingStubNutritionReader()
        let cli = MockNutritionCLI()
        let vm = NutritionTodayViewModel(reader: reader, cli: cli)

        vm.loadToday()
        XCTAssertEqual(vm.loggableItems.count, 2)

        await vm.logItem(flatIndex: 1)

        XCTAssertEqual(cli.logCount, 1)
        XCTAssertEqual(reader.readCount, 2)
        XCTAssertEqual(vm.loggableItems.count, 0)
        if case .loaded(let log) = vm.loadState {
            XCTAssertEqual(log.records.count, 1)
        } else {
            XCTFail("expected loaded after reload")
        }
    }

    func testIsLoggingBlocksSecondLog() async {
        let reader = StubNutritionReader()
        let cli = SlowMockNutritionCLI()
        let vm = NutritionTodayViewModel(reader: reader, cli: cli)

        vm.loadToday()
        let first = Task { await vm.logItem(flatIndex: 1) }
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(vm.isLogging)

        await vm.logItem(flatIndex: 2)
        await first.value

        XCTAssertEqual(cli.logCount, 1)
        XCTAssertEqual(cli.lastName, "燕麦")
    }

    func testMoreThanNineItemsOnlyFirstNineHaveShortcutRange() {
        let panel = NutritionPanel(
            schemaVersion: 1,
            updatedAt: "t",
            dayLabel: "休息日",
            targets: NutritionMacroBucket(kcal: 1, proteinG: 1, carbsG: 1, fatG: 1, sodiumMg: 1),
            consumed: NutritionMacroBucket(kcal: 0, proteinG: 0, carbsG: 0, fatG: 0, sodiumMg: 0),
            remaining: NutritionMacroBucket(kcal: 1, proteinG: 1, carbsG: 1, fatG: 1, sodiumMg: 1),
            suggestions: [
                NutritionPanelSuggestion(
                    label: "菜单",
                    items: (1...10).map {
                        NutritionPanelSuggestionItem(
                            name: "食物\($0)",
                            grams: Double($0 * 10),
                            kcal: 10,
                            proteinG: 1,
                            carbsG: 1,
                            fatG: 0,
                            sodiumMg: 0
                        )
                    },
                    total: nil,
                    withinSlack: true
                ),
            ],
            calorieSlack: 50
        )
        let items = NutritionLoggableItem.flattened(from: panel)
        XCTAssertEqual(items.count, 10)
        XCTAssertEqual(items[8].flatIndex, 9)
        XCTAssertEqual(items[9].flatIndex, 10)
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
        return StubNutritionReader.makeLog(suggestions: [], records: [
            NutritionDailyRecord(name: "燕麦", kcal: 150, proteinG: 5, carbsG: 26, fatG: 2, sodiumMg: 0, weightG: 40),
        ])
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
        records: [NutritionDailyRecord] = []
    ) -> NutritionDailyLog {
        let panel = NutritionPanel(
            schemaVersion: 1,
            updatedAt: "2099-01-01T08:00:00+08:00",
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
