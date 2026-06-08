import XCTest
@testable import MalDaze

final class HermesScheduleModelsTests: XCTestCase {
    func testDecodeTodayResponse() throws {
        let json = """
        {
          "date": "2026-06-08",
          "is_rest_day": false,
          "pending_count": 1,
          "pending": [
            {
              "index": 1,
              "task_id": "lc_review_task_1",
              "title": "Sample",
              "project_id": "lc_review",
              "project_name": "LC",
              "duration_minutes": 45,
              "task_type": "study",
              "scheduled_date": "2026-06-08"
            }
          ],
          "study": {
            "tasks": [
              {
                "project_id": "lc_review",
                "project_name": "LC",
                "task": {
                  "id": "lc_review_task_1",
                  "title": "Sample",
                  "duration_minutes": 45,
                  "auto_roll_days": 2
                }
              }
            ],
            "total_minutes": 45,
            "budget": 90
          },
          "review": { "tasks": [], "total_minutes": 0, "budget": 60 },
          "warnings": []
        }
        """

        let response = try HermesScheduleJSON.decode(HermesTodayResponse.self, from: json)
        let snapshot = LearningTodaySnapshot.make(from: response)

        XCTAssertEqual(response.pendingCount, 1)
        XCTAssertEqual(snapshot.rows.first?.autoRollDays, 2)
    }

    func testDecodeMoveDryRun() throws {
        let json = """
        {
          "action": "move",
          "dry_run": true,
          "task_id": "t1",
          "delta_days": 1,
          "changes": [
            { "task_id": "t1", "title": "A", "old_date": "2026-06-07", "new_date": "2026-06-08" }
          ],
          "affected_count": 1
        }
        """

        let move = try HermesScheduleJSON.decode(HermesMoveResponse.self, from: json)
        XCTAssertTrue(move.dryRun == true)
        XCTAssertEqual(move.changes.count, 1)
        XCTAssertTrue(move.succeeded)
    }

    func testDecodeErrorEnvelope() {
        XCTAssertThrowsError(
            try HermesScheduleJSON.decode(HermesTodayResponse.self, from: #"{"error":"Cannot move task before today"}"#)
        ) { error in
            XCTAssertEqual((error as? HermesCLIError)?.message, "Cannot move task before today")
        }
    }
}
