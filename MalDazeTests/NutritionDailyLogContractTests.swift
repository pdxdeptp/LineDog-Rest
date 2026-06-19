import XCTest
@testable import MalDaze

final class NutritionDailyLogContractTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("nutrition-contract-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testReadValidPanelWithSodiumAndSuggestions() throws {
        let url = tempDir.appendingPathComponent("daily_log.json")
        try fixtureJSON().write(to: url, atomically: true, encoding: .utf8)

        let log = try NutritionDailyLogContractReader(fileURL: url).read()
        XCTAssertEqual(log.dayType, "rest")
        XCTAssertEqual(log.records.count, 1)
        let panel = try XCTUnwrap(log.panel)
        XCTAssertEqual(panel.schemaVersion, 1)
        XCTAssertEqual(panel.dayLabel, "休息日")
        XCTAssertNil(panel.workoutLabel)
        XCTAssertEqual(panel.consumed.sodiumMg, 120)
        XCTAssertEqual(panel.targets.sodiumMg, 2300)
        XCTAssertEqual(panel.suggestions.count, 1)
        XCTAssertEqual(panel.suggestions[0].items[0].name, "燕麦")
        XCTAssertEqual(panel.suggestions[0].items[0].grams, 40)
    }

    func testUnsupportedPanelSchemaFails() {
        let url = tempDir.appendingPathComponent("daily_log.json")
        var json = fixtureJSON()
        json = json.replacingOccurrences(of: "\"schemaVersion\": 1", with: "\"schemaVersion\": 2")
        try? json.write(to: url, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try NutritionDailyLogContractReader(fileURL: url).read()) { error in
            guard case NutritionDailyLogContractError.unsupportedPanelSchema(2) = error else {
                return XCTFail("expected unsupported schema, got \(error)")
            }
        }
    }

    func testReadTrainingDayWorkoutLabel() throws {
        let url = tempDir.appendingPathComponent("daily_log.json")
        try trainingFixtureJSON().write(to: url, atomically: true, encoding: .utf8)

        let panel = try XCTUnwrap(try NutritionDailyLogContractReader(fileURL: url).read().panel)
        XCTAssertEqual(panel.dayLabel, "训练日")
        XCTAssertEqual(panel.workoutLabel, "练胸")
    }

    func testFlattenSkipsSuggestionsOutsideCalorieSlack() throws {
        let url = tempDir.appendingPathComponent("daily_log.json")
        var json = fixtureJSON()
        json = json.replacingOccurrences(
            of: "\"within_slack\": true",
            with: "\"within_slack\": false"
        )
        try json.write(to: url, atomically: true, encoding: .utf8)
        let panel = try XCTUnwrap(try NutritionDailyLogContractReader(fileURL: url).read().panel)
        XCTAssertTrue(NutritionLoggableItem.flattened(from: panel).isEmpty)
    }

    func testFlattenLoggableItems() throws {
        let url = tempDir.appendingPathComponent("daily_log.json")
        try fixtureJSON().write(to: url, atomically: true, encoding: .utf8)
        let panel = try XCTUnwrap(try NutritionDailyLogContractReader(fileURL: url).read().panel)
        let items = NutritionLoggableItem.flattened(from: panel)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].flatIndex, 1)
        XCTAssertEqual(items[1].flatIndex, 2)
        XCTAssertEqual(items[1].name, "蓝莓")
    }

    func testReadTargetBreakdown() throws {
        let url = tempDir.appendingPathComponent("daily_log.json")
        try breakdownFixtureJSON().write(to: url, atomically: true, encoding: .utf8)

        let panel = try XCTUnwrap(try NutritionDailyLogContractReader(fileURL: url).read().panel)
        let breakdown = try XCTUnwrap(panel.targetBreakdown)
        XCTAssertEqual(breakdown.targetKcal, 1800)
        XCTAssertEqual(breakdown.layers.count, 3)
        XCTAssertEqual(breakdown.layers[0].id, "bmr")
        XCTAssertEqual(breakdown.layers[0].kcal, 1600)
        XCTAssertEqual(breakdown.macroRules?.proteinGPerKg, 2.0)
    }

    private func breakdownFixtureJSON() -> String {
        """
        {
          "date": "2099-01-01",
          "day_type": "rest",
          "records": [],
          "panel": {
            "schemaVersion": 1,
            "updatedAt": "2099-01-01T08:00:00+08:00",
            "dayLabel": "休息日",
            "targets": { "kcal": 1800, "protein_g": 120, "carbs_g": 180, "fat_g": 60, "sodium_mg": 2300 },
            "consumed": { "kcal": 0, "protein_g": 0, "carbs_g": 0, "fat_g": 0, "sodium_mg": 0 },
            "remaining": { "kcal": 1800, "protein_g": 120, "carbs_g": 180, "fat_g": 60, "sodium_mg": 2300 },
            "suggestions": [],
            "calorieSlack": 50,
            "targetBreakdown": {
              "targetKcal": 1800,
              "phaseLabel": "减脂期",
              "layers": [
                { "id": "bmr", "label": "基础代谢 BMR", "kcal": 1600 },
                { "id": "phase", "label": "减脂期调整", "kcal": -300, "resultKcal": 1800 },
                { "id": "total", "label": "今日目标", "kcal": 1800 }
              ],
              "macroRules": { "proteinGPerKg": 2.0, "fatGPerKg": 0.8, "note": "碳水由剩余热量填充" }
            }
          }
        }
        """
    }

    private func trainingFixtureJSON() -> String {
        """
        {
          "date": "2099-01-02",
          "day_type": "training",
          "workout_split": "chest",
          "records": [],
          "panel": {
            "schemaVersion": 1,
            "updatedAt": "2099-01-02T08:00:00+08:00",
            "dayLabel": "训练日",
            "workoutLabel": "练胸",
            "targets": { "kcal": 2200, "protein_g": 140, "carbs_g": 200, "fat_g": 70, "sodium_mg": 2300 },
            "consumed": { "kcal": 0, "protein_g": 0, "carbs_g": 0, "fat_g": 0, "sodium_mg": 0 },
            "remaining": { "kcal": 2200, "protein_g": 140, "carbs_g": 200, "fat_g": 70, "sodium_mg": 2300 },
            "suggestions": [],
            "calorieSlack": 50
          }
        }
        """
    }

    private func fixtureJSON() -> String {
        """
        {
          "date": "2099-01-01",
          "day_type": "rest",
          "records": [
            { "name": "燕麦", "kcal": 188, "protein_g": 6, "carbs_g": 32, "fat_g": 3, "sodium_mg": 120, "weight_g": 50 }
          ],
          "panel": {
            "schemaVersion": 1,
            "updatedAt": "2099-01-01T08:00:00+08:00",
            "dayLabel": "休息日",
            "targets": { "kcal": 1800, "protein_g": 120, "carbs_g": 180, "fat_g": 60, "sodium_mg": 2300 },
            "consumed": { "kcal": 188, "protein_g": 6, "carbs_g": 32, "fat_g": 3, "sodium_mg": 120 },
            "remaining": { "kcal": 1612, "protein_g": 114, "carbs_g": 148, "fat_g": 57, "sodium_mg": 2180 },
            "suggestions": [
              {
                "label": "建议菜单",
                "items": [
                  { "name": "燕麦", "grams": 40, "kcal": 150, "protein_g": 5, "carbs_g": 26, "fat_g": 2, "sodium_mg": 0 },
                  { "name": "蓝莓", "grams": 80, "kcal": 46, "protein_g": 1, "carbs_g": 11, "fat_g": 0, "sodium_mg": 1 }
                ],
                "total": { "kcal": 196, "protein_g": 6, "carbs_g": 37, "fat_g": 2, "sodium_mg": 1 },
                "within_slack": true
              }
            ],
            "calorieSlack": 50
          }
        }
        """
    }
}
