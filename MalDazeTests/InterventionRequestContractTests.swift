import XCTest
@testable import MalDaze

final class InterventionRequestContractTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("intervention-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testReadValidCountdownContract() throws {
        let url = tempDir.appendingPathComponent("intervention_request.json")
        try """
        {
          "schemaVersion": 1,
          "id": "550e8400-e29b-41d4-a716-446655440000",
          "kind": "countdown",
          "minutes": 30,
          "title": "红薯煮好了",
          "requestedAt": "2026-06-07T18:30:00Z",
          "expiresAt": "2026-06-08T18:30:00Z"
        }
        """.write(to: url, atomically: true, encoding: .utf8)

        let contract = try InterventionRequestContractReader(fileURL: url).read()
        XCTAssertEqual(contract.schemaVersion, 1)
        XCTAssertEqual(contract.id, "550e8400-e29b-41d4-a716-446655440000")
        XCTAssertEqual(contract.kind, .countdown)
        XCTAssertEqual(contract.minutes, 30)
        XCTAssertEqual(contract.title, "红薯煮好了")
        XCTAssertNotNil(contract.requestedAt)
        XCTAssertNotNil(contract.expiresAt)
    }

    func testMissingMinutesOnCountdownFails() {
        let url = tempDir.appendingPathComponent("intervention_request.json")
        try? """
        {
          "schemaVersion": 1,
          "id": "x",
          "kind": "countdown",
          "title": "t",
          "requestedAt": "2026-06-07T18:30:00Z"
        }
        """.write(to: url, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try InterventionRequestContractReader(fileURL: url).read()) { error in
            guard case InterventionRequestContractError.missingField("minutes") = error else {
                return XCTFail("expected missing minutes, got \(error)")
            }
        }
    }

    func testInvalidKindFails() {
        let url = tempDir.appendingPathComponent("intervention_request.json")
        try? """
        {
          "schemaVersion": 1,
          "id": "x",
          "kind": "nope",
          "title": "t",
          "requestedAt": "2026-06-07T18:30:00Z"
        }
        """.write(to: url, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try InterventionRequestContractReader(fileURL: url).read()) { error in
            guard case InterventionRequestContractError.invalidKind("nope") = error else {
                return XCTFail("expected invalid kind, got \(error)")
            }
        }
    }

    func testIsExpired() throws {
        let past = Date().addingTimeInterval(-3600)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let contract = InterventionRequestContract(
            schemaVersion: 1,
            id: "id",
            kind: .bell,
            minutes: nil,
            title: "t",
            requestedAt: past,
            expiresAt: Date().addingTimeInterval(-60)
        )
        XCTAssertTrue(contract.isExpired(at: Date()))
    }

    func testCountdownEndDate() throws {
        let requested = Date(timeIntervalSince1970: 1_000_000)
        let contract = InterventionRequestContract(
            schemaVersion: 1,
            id: "id",
            kind: .countdown,
            minutes: 30,
            title: "t",
            requestedAt: requested,
            expiresAt: nil
        )
        XCTAssertEqual(
            contract.countdownEndDate,
            requested.addingTimeInterval(30 * 60)
        )
    }
}
