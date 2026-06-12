import XCTest
@testable import MalDaze

final class NutritionRecommendationContractTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("nutrition-recommendation-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testDecodesSchemaVersionOneAvailableSnapshot() throws {
        let url = tempDir.appendingPathComponent("recommendation.json")
        try availableFixture().write(to: url, atomically: true, encoding: .utf8)

        let snapshot = try NutritionRecommendationContractReader(fileURL: url).read()

        XCTAssertEqual(snapshot.schemaVersion, 1)
        XCTAssertEqual(snapshot.date, "2099-01-01")
        XCTAssertEqual(snapshot.generatedAt, "2099-01-01T08:05:00+08:00")
        XCTAssertEqual(snapshot.source.kind, "morning_briefing")
        XCTAssertEqual(snapshot.source.channel, "feishu")
        XCTAssertEqual(snapshot.basedOn.dailyLogDate, "2099-01-01")
        XCTAssertEqual(snapshot.basedOn.dailyLogPanelUpdatedAt, "2099-01-01T08:00:00+08:00")
        XCTAssertEqual(snapshot.basedOn.recordsCount, 2)
        XCTAssertEqual(snapshot.state, .available)
        XCTAssertEqual(snapshot.summary, "今天还需要补蛋白和一点碳水，脂肪空间不多。")
        XCTAssertEqual(snapshot.suggestions[0].label, "现在最合适")
        XCTAssertEqual(snapshot.suggestions[0].rationale, "补蛋白，热量温和。")
        XCTAssertEqual(snapshot.suggestions[0].warnings, ["脂肪空间不多"])
        XCTAssertEqual(snapshot.suggestions[0].items[0].displayName, "去脂希腊酸奶 250g")
        XCTAssertEqual(snapshot.suggestions[0].items[0].name, "希腊酸奶·去脂")
        XCTAssertEqual(snapshot.suggestions[0].items[0].grams, 250)
        XCTAssertEqual(snapshot.suggestions[0].items[0].kcal, 150)
        XCTAssertTrue(snapshot.suggestions[0].items[0].loggable)
        XCTAssertEqual(snapshot.suggestions[0].items[1].displayName, "再喝一杯水")
        XCTAssertFalse(snapshot.suggestions[0].items[1].loggable)
        XCTAssertNil(snapshot.suggestions[0].items[1].name)
        XCTAssertNil(snapshot.suggestions[0].items[1].grams)
        XCTAssertNil(snapshot.suggestions[0].items[1].kcal)
    }

    func testUnsupportedSchemaVersionFails() throws {
        let url = tempDir.appendingPathComponent("recommendation.json")
        try availableFixture()
            .replacingOccurrences(of: "\"schemaVersion\": 1", with: "\"schemaVersion\": 2")
            .write(to: url, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try NutritionRecommendationContractReader(fileURL: url).read()) { error in
            guard case NutritionRecommendationContractError.unsupportedSchema(2) = error else {
                return XCTFail("expected unsupported schema, got \(error)")
            }
        }
    }

    func testMissingRecommendationFileFailsAsMissing() {
        let url = tempDir.appendingPathComponent("recommendation.json")

        XCTAssertThrowsError(try NutritionRecommendationContractReader(fileURL: url).read()) { error in
            guard case NutritionRecommendationContractError.fileNotFound = error else {
                return XCTFail("expected missing file, got \(error)")
            }
        }
    }

    func testLoggableItemRequiresNameAndPositiveGrams() throws {
        let url = tempDir.appendingPathComponent("recommendation.json")
        try availableFixture()
            .replacingOccurrences(of: "\"name\": \"希腊酸奶·去脂\",", with: "")
            .write(to: url, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try NutritionRecommendationContractReader(fileURL: url).read()) { error in
            guard case NutritionRecommendationContractError.invalidJSON = error else {
                return XCTFail("expected invalid JSON contract, got \(error)")
            }
        }

        try availableFixture()
            .replacingOccurrences(of: "\"grams\": 250", with: "\"grams\": 0")
            .write(to: url, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try NutritionRecommendationContractReader(fileURL: url).read()) { error in
            guard case NutritionRecommendationContractError.invalidJSON = error else {
                return XCTFail("expected invalid JSON contract, got \(error)")
            }
        }
    }

    private func availableFixture() -> String {
        """
        {
          "schemaVersion": 1,
          "date": "2099-01-01",
          "generatedAt": "2099-01-01T08:05:00+08:00",
          "source": { "kind": "morning_briefing", "channel": "feishu" },
          "basedOn": {
            "dailyLogDate": "2099-01-01",
            "dailyLogPanelUpdatedAt": "2099-01-01T08:00:00+08:00",
            "recordsCount": 2
          },
          "state": "available",
          "summary": "今天还需要补蛋白和一点碳水，脂肪空间不多。",
          "suggestions": [
            {
              "label": "现在最合适",
              "rationale": "补蛋白，热量温和。",
              "warnings": ["脂肪空间不多"],
              "items": [
                {
                  "displayName": "去脂希腊酸奶 250g",
                  "name": "希腊酸奶·去脂",
                  "grams": 250,
                  "kcal": 150,
                  "loggable": true
                },
                {
                  "displayName": "再喝一杯水",
                  "loggable": false
                }
              ]
            }
          ]
        }
        """
    }
}
