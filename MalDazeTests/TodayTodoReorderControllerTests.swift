import CoreGraphics
import XCTest
@testable import MalDaze

final class TodayTodoReorderGeometryTests: XCTestCase {
    private let a = UUID()
    private let b = UUID()
    private let c = UUID()

    private var baseOrder: [UUID] { [a, b, c] }

    private var frames: [UUID: CGRect] {
        [
            a: CGRect(x: 0, y: 0, width: 100, height: 20),
            b: CGRect(x: 0, y: 22, width: 100, height: 20),
            c: CGRect(x: 0, y: 44, width: 100, height: 30),
        ]
    }

    private var heights: [UUID: CGFloat] {
        [a: 20, b: 20, c: 30]
    }

    func testTargetIndexUsesSourceExcludedSpatialOrder() {
        let centerAboveA: CGFloat = 5
        XCTAssertEqual(
            TodayTodoReorderGeometry.rawTargetIndex(
                floatingCenterY: centerAboveA,
                baseOrder: baseOrder,
                sourceId: c,
                rowFrames: frames
            ),
            0
        )

        let centerBetweenAB: CGFloat = 21
        XCTAssertEqual(
            TodayTodoReorderGeometry.rawTargetIndex(
                floatingCenterY: centerBetweenAB,
                baseOrder: baseOrder,
                sourceId: c,
                rowFrames: frames
            ),
            1
        )

        let centerBelowB: CGFloat = 80
        XCTAssertEqual(
            TodayTodoReorderGeometry.rawTargetIndex(
                floatingCenterY: centerBelowB,
                baseOrder: baseOrder,
                sourceId: c,
                rowFrames: frames
            ),
            2
        )
    }

    func testProjectedOffsetsMoveAffectedNeighborsOnly() {
        let offsetB = TodayTodoReorderGeometry.rowOffset(
            entryId: b,
            sourceId: c,
            sourceIndex: 2,
            targetIndex: 1,
            baseOrder: baseOrder,
            rowFrames: frames,
            rowHeights: heights,
            listRowSpacing: 2
        )
        XCTAssertNotEqual(offsetB, 0)

        let offsetA = TodayTodoReorderGeometry.rowOffset(
            entryId: a,
            sourceId: c,
            sourceIndex: 2,
            targetIndex: 1,
            baseOrder: baseOrder,
            rowFrames: frames,
            rowHeights: heights,
            listRowSpacing: 2
        )
        XCTAssertEqual(offsetA, 0, accuracy: 0.001)
    }

    func testSettleYUsesProjectedTargetNotSource() {
        let geometry = TodayTodoReorderGeometry.projectedGeometry(
            baseOrder: baseOrder,
            rowFrames: frames,
            rowHeights: heights,
            sourceId: c,
            targetIndex: 0,
            listRowSpacing: 2
        )
        XCTAssertEqual(geometry.projectedMinY[c] ?? -1, 0, accuracy: 0.001)
        XCTAssertNotEqual(geometry.projectedMinY[c] ?? -1, frames[c]?.minY ?? -1)
    }

    func testProjectedGeometryPreservesTotalHeight() {
        let initial = TodayTodoReorderGeometry.projectedGeometry(
            baseOrder: baseOrder,
            rowFrames: frames,
            rowHeights: heights,
            sourceId: c,
            targetIndex: 2,
            listRowSpacing: 2
        )
        let moved = TodayTodoReorderGeometry.projectedGeometry(
            baseOrder: baseOrder,
            rowFrames: frames,
            rowHeights: heights,
            sourceId: c,
            targetIndex: 0,
            listRowSpacing: 2
        )
        XCTAssertEqual(initial.totalHeight, moved.totalHeight, accuracy: 0.001)
    }
}

@MainActor
final class TodayTodoLongPressGestureTrackerTests: XCTestCase {
    private func makeEvent(x: CGFloat, y: CGFloat) -> NSEvent {
        NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: NSPoint(x: x, y: y),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        )!
    }

    func testQuickClickEditsWithoutLongPress() {
        var now: TimeInterval = 0
        let tracker = TodayTodoLongPressGestureTracker(
            clock: { now },
            schedule: { _, _ in }
        )
        let down = makeEvent(x: 0, y: 0)
        let outcome = tracker.mouseDown(reorderEnabled: true, event: down)
        XCTAssertEqual(outcome, .none)

        let (upOutcome, editEvent) = tracker.mouseUp()
        XCTAssertEqual(upOutcome, .quickClickEdit)
        XCTAssertNotNil(editEvent)
    }

    func testLongPressWithoutDragDoesNotEdit() {
        var now: TimeInterval = 0
        var scheduled: (() -> Void)?
        let tracker = TodayTodoLongPressGestureTracker(
            clock: { now },
            schedule: { _, block in scheduled = block }
        )
        _ = tracker.mouseDown(reorderEnabled: true, event: makeEvent(x: 0, y: 0))
        now += 0.36
        scheduled?()

        let (upOutcome, editEvent) = tracker.mouseUp()
        XCTAssertEqual(upOutcome, .longPressReleasedWithoutDrag)
        XCTAssertNil(editEvent)
    }

    func testFourPointMoveActivatesReorder() {
        var now: TimeInterval = 0
        var scheduled: (() -> Void)?
        let tracker = TodayTodoLongPressGestureTracker(
            clock: { now },
            schedule: { _, block in scheduled = block }
        )
        _ = tracker.mouseDown(reorderEnabled: true, event: makeEvent(x: 0, y: 0))
        now += 0.36
        scheduled?()

        let dragOutcome = tracker.mouseDragged(event: makeEvent(x: 5, y: 0))
        XCTAssertEqual(dragOutcome, .reorderActivated)
    }
}

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

    func testBaseOrderRemainsImmutableWhileTargetChanges() {
        let controller = TodayTodoReorderController()
        let a = UUID()
        let b = UUID()
        let c = UUID()
        let entries = [
            makeEntry(id: a, title: "A", sortIndex: 0),
            makeEntry(id: b, title: "B", sortIndex: 1),
            makeEntry(id: c, title: "C", sortIndex: 2),
        ]
        let frames = [
            TodayTodoRowFrame(id: a, frame: CGRect(x: 0, y: 0, width: 100, height: 20)),
            TodayTodoRowFrame(id: b, frame: CGRect(x: 0, y: 22, width: 100, height: 20)),
            TodayTodoRowFrame(id: c, frame: CGRect(x: 0, y: 44, width: 100, height: 20)),
        ]
        controller.updateRowFrames(frames)
        controller.beginDrag(entryId: b, entries: entries, pointerContentY: 25)
        let initialBase = controller.baseOrder

        controller.updateDrag(pointerContentY: 0, viewportY: 10)
        XCTAssertEqual(controller.baseOrder, initialBase)
        XCTAssertNotEqual(controller.targetIndex, controller.sourceIndex)
    }

    func testSettlingCommitsOnceViaCompletion() {
        let controller = TodayTodoReorderController()
        let a = UUID()
        let b = UUID()
        let entries = [
            makeEntry(id: a, title: "A", sortIndex: 0),
            makeEntry(id: b, title: "B", sortIndex: 1),
        ]
        controller.updateRowFrames([
            TodayTodoRowFrame(id: a, frame: CGRect(x: 0, y: 0, width: 100, height: 20)),
            TodayTodoRowFrame(id: b, frame: CGRect(x: 0, y: 22, width: 100, height: 20)),
        ])
        controller.beginDrag(entryId: b, entries: entries, pointerContentY: 25)
        controller.updateDrag(pointerContentY: 0, viewportY: 10)
        XCTAssertNotEqual(controller.targetIndex, controller.sourceIndex)

        var commitCount = 0
        controller.endDrag { _, _ in commitCount += 1 }
        XCTAssertEqual(controller.phase, .settling)
        XCTAssertEqual(commitCount, 0)

        controller.finishSettlingAnimation()
        XCTAssertEqual(commitCount, 1)
        XCTAssertEqual(controller.phase, .idle)
    }

    func testPointerModelUpdatesDoNotChangeTargetIndex() {
        let controller = TodayTodoReorderController()
        let a = UUID()
        let b = UUID()
        let entries = [
            makeEntry(id: a, title: "A", sortIndex: 0),
            makeEntry(id: b, title: "B", sortIndex: 1),
        ]
        controller.updateRowFrames([
            TodayTodoRowFrame(id: a, frame: CGRect(x: 0, y: 0, width: 100, height: 20)),
            TodayTodoRowFrame(id: b, frame: CGRect(x: 0, y: 22, width: 100, height: 20)),
        ])
        controller.beginDrag(entryId: b, entries: entries, pointerContentY: 5)
        let target = controller.targetIndex

        controller.updateDrag(pointerContentY: 6, viewportY: 6)
        controller.updateDrag(pointerContentY: 7, viewportY: 7)
        XCTAssertEqual(controller.targetIndex, target)
    }

    func testIdentityChangeAbortsWithoutCommit() {
        let controller = TodayTodoReorderController()
        let a = UUID()
        let b = UUID()
        let entries = [
            makeEntry(id: a, title: "A", sortIndex: 0),
            makeEntry(id: b, title: "B", sortIndex: 1),
        ]
        controller.updateRowFrames([
            TodayTodoRowFrame(id: a, frame: CGRect(x: 0, y: 0, width: 100, height: 20)),
            TodayTodoRowFrame(id: b, frame: CGRect(x: 0, y: 22, width: 100, height: 20)),
        ])
        controller.beginDrag(entryId: b, entries: entries, pointerContentY: 5)

        let changed = [entries[0], TodayTodoEntry(
            id: UUID(),
            title: "X",
            dateISO: "2026-06-18",
            rolledFromDateISO: nil,
            isCompleted: false,
            createdAt: .distantPast,
            completedAt: nil,
            sortIndex: 1
        )]
        controller.updateDrag(pointerContentY: 5, viewportY: 5)
        XCTAssertFalse(controller.validateEntriesIdentity(changed))
    }
}
