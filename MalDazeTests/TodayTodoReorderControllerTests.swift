import CoreGraphics
import XCTest
@testable import MalDaze

@MainActor
final class TodayTodoReorderControllerTests: XCTestCase {
    private func makeEntry(id: UUID, title: String, sortIndex: Int) -> TodayTodoEntry {
        TodayTodoEntry(
            id: id,
            title: title,
            dateISO: "2026-06-18",
            rolledFromDateISO: nil,
            isCompleted: false,
            createdAt: Date(timeIntervalSince1970: 0),
            completedAt: nil,
            sortIndex: sortIndex
        )
    }

    func testListPointerYFlipsAppKitLocalYToTopLeft() {
        let listHeight: CGFloat = 200
        XCTAssertEqual(
            TodayTodoReorderPointerBridge.listPointerY(appKitLocalY: 0, listHeight: listHeight),
            200,
            accuracy: 0.001
        )
        XCTAssertEqual(
            TodayTodoReorderPointerBridge.listPointerY(appKitLocalY: 200, listHeight: listHeight),
            0,
            accuracy: 0.001
        )
        XCTAssertEqual(
            TodayTodoReorderPointerBridge.listPointerY(appKitLocalY: 50, listHeight: listHeight),
            150,
            accuracy: 0.001
        )
    }

    func testInsertionIndexUsesFrozenTopLeftFrames() {
        let a = UUID()
        let b = UUID()
        let c = UUID()
        let order = [a, b, c]
        let frames: [UUID: CGRect] = [
            a: CGRect(x: 0, y: 0, width: 100, height: 20),
            b: CGRect(x: 0, y: 22, width: 100, height: 20),
            c: CGRect(x: 0, y: 44, width: 100, height: 20),
        ]

        XCTAssertEqual(
            TodayTodoReorderController.insertionIndex(for: 5, order: order, rowFrames: frames),
            0
        )
        XCTAssertEqual(
            TodayTodoReorderController.insertionIndex(for: 21, order: order, rowFrames: frames),
            1
        )
        XCTAssertEqual(
            TodayTodoReorderController.insertionIndex(for: 33, order: order, rowFrames: frames),
            2
        )
        XCTAssertEqual(
            TodayTodoReorderController.insertionIndex(for: 80, order: order, rowFrames: frames),
            3
        )
    }

    func testPreviewOrderUpdatesDuringDragWithoutPersisting() {
        let controller = TodayTodoReorderController()
        let a = UUID()
        let b = UUID()
        let c = UUID()
        let entries = [
            makeEntry(id: a, title: "A", sortIndex: 0),
            makeEntry(id: b, title: "B", sortIndex: 1),
            makeEntry(id: c, title: "C", sortIndex: 2),
        ]
        let frames: [UUID: CGRect] = [
            a: CGRect(x: 0, y: 0, width: 100, height: 20),
            b: CGRect(x: 0, y: 22, width: 100, height: 20),
            c: CGRect(x: 0, y: 44, width: 100, height: 20),
        ]
        controller.updateRowFrames(frames.map { TodayTodoRowFrame(id: $0.key, frame: $0.value) })

        controller.beginDrag(entryId: c, entries: entries, pointerY: 10)
        XCTAssertEqual(controller.phase, .dragging)
        XCTAssertEqual(controller.previewOrder, [a, b, c])

        controller.updateDrag(pointerY: 21, entries: entries)
        XCTAssertEqual(controller.previewOrder, [a, c, b])
        XCTAssertEqual(controller.phase, .dragging)

        var commitCalled = false
        controller.endDrag { _, _ in
            commitCalled = true
        }
        XCTAssertEqual(controller.phase, .settling)
        XCTAssertFalse(commitCalled)

        let settleExpectation = expectation(description: "settling completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + TodayTodoReorderMetrics.settlingDuration + 0.05) {
            settleExpectation.fulfill()
        }
        wait(for: [settleExpectation], timeout: 2)
        XCTAssertTrue(commitCalled)
        XCTAssertEqual(controller.phase, .idle)
    }

    func testCancelDragDoesNotCommit() {
        let controller = TodayTodoReorderController()
        let a = UUID()
        let b = UUID()
        let entries = [
            makeEntry(id: a, title: "A", sortIndex: 0),
            makeEntry(id: b, title: "B", sortIndex: 1),
        ]
        let frames: [UUID: CGRect] = [
            a: CGRect(x: 0, y: 0, width: 100, height: 20),
            b: CGRect(x: 0, y: 22, width: 100, height: 20),
        ]
        controller.updateRowFrames(frames.map { TodayTodoRowFrame(id: $0.key, frame: $0.value) })
        controller.beginDrag(entryId: b, entries: entries, pointerY: 5)
        controller.updateDrag(pointerY: 5, entries: entries)

        var commitCalled = false
        controller.cancelDrag()

        XCTAssertEqual(controller.phase, .cancelling)
        XCTAssertFalse(commitCalled)

        let cancelExpectation = expectation(description: "cancel completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + TodayTodoReorderMetrics.settlingDuration + 0.05) {
            cancelExpectation.fulfill()
        }
        wait(for: [cancelExpectation], timeout: 2)
        XCTAssertFalse(commitCalled)
        XCTAssertEqual(controller.phase, .idle)
    }
}
