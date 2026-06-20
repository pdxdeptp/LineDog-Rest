import CoreGraphics
import XCTest
@testable import MalDaze

final class TodayTodoLayoutPolicyTests: XCTestCase {
    private let spacing: CGFloat = 2
    private let draft: CGFloat = 28
    private let available: CGFloat = 200
    private let liveWidth: CGFloat = 320

    private func resolve(
        listHeight: CGFloat?,
        draftRowHeight: CGFloat? = 28,
        draftMinimumHeight: CGFloat = 24,
        measuredListWidth: CGFloat? = 320,
        liveWidth: CGFloat = 320,
        availableHeight: CGFloat? = nil
    ) -> TodayTodoLayoutResolution {
        TodayTodoLayoutPolicy.resolve(
            listHeight: listHeight,
            draftRowHeight: draftRowHeight,
            draftMinimumHeight: draftMinimumHeight,
            measuredListWidth: measuredListWidth,
            liveWidth: liveWidth,
            availableHeight: availableHeight ?? available,
            listRowSpacing: spacing
        )
    }

    // MARK: - 1.1 Resolution table

    func testNilListHeightUsesMeasuringMode() {
        let resolution = resolve(listHeight: nil)
        XCTAssertEqual(resolution.mode, .measuring)
        XCTAssertEqual(resolution.listViewportHeight, 170, accuracy: 0.001)
        XCTAssertFalse(resolution.listScrollEnabled)
    }

    func testListAtFitCapacityUsesCompactMode() {
        let resolution = resolve(listHeight: 169.5)
        XCTAssertEqual(resolution.mode, .compact)
        XCTAssertEqual(resolution.listViewportHeight, 169.5, accuracy: 0.001)
        XCTAssertFalse(resolution.listScrollEnabled)
    }

    func testListJustAboveFitCapacityUsesPinnedMode() {
        let resolution = resolve(listHeight: 169.51)
        XCTAssertEqual(resolution.mode, .pinned)
        XCTAssertEqual(resolution.listViewportHeight, 170, accuracy: 0.001)
        XCTAssertTrue(resolution.listScrollEnabled)
    }

    func testOverflowingListUsesPinnedModeWithFullCapacity() {
        let resolution = resolve(listHeight: 220)
        XCTAssertEqual(resolution.mode, .pinned)
        XCTAssertEqual(resolution.listViewportHeight, 170, accuracy: 0.001)
        XCTAssertTrue(resolution.listScrollEnabled)
    }

    func testUndersizedAvailableHeightUsesZeroViewportPinned() {
        let resolution = resolve(listHeight: 220, availableHeight: 20)
        XCTAssertEqual(resolution.mode, .pinned)
        XCTAssertEqual(resolution.listViewportHeight, 0, accuracy: 0.001)
        XCTAssertFalse(resolution.listScrollEnabled)
    }

    // MARK: - 1.2 Edge inputs

    func testNegativeListHeightClampsToZeroCompact() {
        let resolution = resolve(listHeight: -10)
        XCTAssertEqual(resolution.mode, .compact)
        XCTAssertEqual(resolution.listViewportHeight, 0, accuracy: 0.001)
        XCTAssertFalse(resolution.listScrollEnabled)
    }

    func testNonFiniteListHeightUsesMeasuringMode() {
        let resolution = resolve(listHeight: CGFloat.nan)
        XCTAssertEqual(resolution.mode, .measuring)
        XCTAssertFalse(resolution.listScrollEnabled)
    }

    func testMissingDraftMeasurementUsesMeasuringMode() {
        let resolution = resolve(listHeight: 100, draftRowHeight: nil)
        XCTAssertEqual(resolution.mode, .measuring)
        XCTAssertFalse(resolution.listScrollEnabled)
    }

    func testWidthMismatchWithinToleranceStillResolves() {
        let resolution = resolve(
            listHeight: 100,
            measuredListWidth: 320.4,
            liveWidth: 320
        )
        XCTAssertEqual(resolution.mode, .compact)
    }

    func testWidthMismatchAboveToleranceUsesMeasuringMode() {
        let resolution = resolve(
            listHeight: 100,
            measuredListWidth: 320.51,
            liveWidth: 320
        )
        XCTAssertEqual(resolution.mode, .measuring)
        XCTAssertFalse(resolution.listScrollEnabled)
    }

    func testDraftMinimumAboveMeasuredRowUsesHigherCapacity() {
        let resolution = resolve(
            listHeight: 100,
            draftRowHeight: 28,
            draftMinimumHeight: 40
        )
        XCTAssertEqual(resolution.mode, .compact)
        XCTAssertEqual(resolution.listViewportHeight, 100, accuracy: 0.001)
    }

    func testDraftMinimumBelowMeasuredRowUsesMeasuredRow() {
        let resolution = resolve(
            listHeight: 100,
            draftRowHeight: 40,
            draftMinimumHeight: 24
        )
        XCTAssertEqual(resolution.mode, .compact)
    }

    func testDraftHeight120UsesFullCapacity() {
        let resolution = resolve(
            listHeight: 200,
            draftRowHeight: 120,
            draftMinimumHeight: 120,
            availableHeight: 200
        )
        XCTAssertEqual(resolution.mode, .pinned)
        XCTAssertEqual(resolution.listViewportHeight, 78, accuracy: 0.001)
        XCTAssertTrue(resolution.listScrollEnabled)
    }

    func testVerticalCapacityChangeRecomputesImmediately() {
        let compact = resolve(listHeight: 100, availableHeight: 200)
        XCTAssertEqual(compact.mode, .compact)

        let pinned = resolve(listHeight: 100, availableHeight: 80)
        XCTAssertEqual(pinned.mode, .pinned)
        XCTAssertEqual(pinned.listViewportHeight, 50, accuracy: 0.001)
    }

    // MARK: - 1.3 Measured geometry

    func testMeasuredGeometryMergeListFirst() {
        var merged = TodayTodoMeasuredGeometry()
        merged.merge(TodayTodoMeasuredGeometry(listSize: CGSize(width: 320, height: 100), draftRowHeight: nil))
        merged.merge(TodayTodoMeasuredGeometry(listSize: nil, draftRowHeight: 28))
        XCTAssertTrue(merged.isComplete)
        XCTAssertEqual(merged.listSize?.height ?? 0, 100, accuracy: 0.001)
        XCTAssertEqual(merged.draftRowHeight ?? 0, 28, accuracy: 0.001)
    }

    func testMeasuredGeometryMergeDraftFirst() {
        var merged = TodayTodoMeasuredGeometry()
        merged.merge(TodayTodoMeasuredGeometry(listSize: nil, draftRowHeight: 28))
        merged.merge(TodayTodoMeasuredGeometry(listSize: CGSize(width: 320, height: 100), draftRowHeight: nil))
        XCTAssertTrue(merged.isComplete)
    }

    func testIncompleteSnapshotIsNotComplete() {
        let geometry = TodayTodoMeasuredGeometry(listSize: CGSize(width: 320, height: 100), draftRowHeight: nil)
        XCTAssertFalse(geometry.isComplete)
    }

    func testInvalidSnapshotIsNotComplete() {
        let geometry = TodayTodoMeasuredGeometry(
            listSize: CGSize(width: 320, height: CGFloat.nan),
            draftRowHeight: 28
        )
        XCTAssertFalse(geometry.isComplete)
    }

    func testPreferenceKeyReducePreservesLastCompleteFieldWhenPartialUpdateArrives() {
        var current = TodayTodoMeasuredGeometry(
            listSize: CGSize(width: 320, height: 100),
            draftRowHeight: 28
        )
        current.merge(TodayTodoMeasuredGeometry(listSize: CGSize(width: 320, height: 120), draftRowHeight: nil))
        XCTAssertTrue(current.isComplete)
        XCTAssertEqual(current.listSize?.height ?? 0, 120, accuracy: 0.001)
        XCTAssertEqual(current.draftRowHeight ?? 0, 28, accuracy: 0.001)
    }
}
