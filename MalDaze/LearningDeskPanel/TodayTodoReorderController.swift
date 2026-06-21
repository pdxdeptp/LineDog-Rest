import AppKit
import Combine
import SwiftUI

@MainActor
final class TodayTodoReorderController: ObservableObject {
    @Published private(set) var phase: TodayTodoReorderPhase = .idle
    @Published private(set) var draggingEntryId: UUID?
    @Published private(set) var sourceIndex: Int = 0
    @Published private(set) var targetIndex: Int = 0
    @Published private(set) var baseOrder: [UUID] = []
    @Published private(set) var frozenRowFrames: [UUID: CGRect] = [:]
    @Published private(set) var edgeScrollVelocity: CGFloat = 0
    @Published private(set) var settleOverlayMinY: CGFloat?
    @Published private(set) var sessionGeneration: UInt = 0

    let pointerModel = TodayTodoDragPointerModel()

    private var frozenRowHeights: [UUID: CGFloat] = [:]
    private var grabOffsetY: CGFloat = 0
    private var listViewportHeight: CGFloat = 0
    private var listRowSpacing: CGFloat = 2
    private var validRegionInWindow: CGRect = .zero
    private var pendingCommit: ((UUID, Int) -> Void)?
    private var completionGeneration: UInt = 0
    private var escMonitor: Any?
    private var listContentHeight: CGFloat = 0

    weak var listPointerView: TodayTodoListPointerView?

    var springAnimation: Animation {
        .spring(
            response: TodayTodoReorderMetrics.springResponse,
            dampingFraction: TodayTodoReorderMetrics.springDamping
        )
    }

    var showsDragOverlay: Bool {
        switch phase {
        case .pressing:
            return false
        case .dragging, .settling, .cancelling:
            return draggingEntryId != nil
        case .idle:
            return false
        }
    }

    var showsPressingLift: Bool {
        phase == .pressing && draggingEntryId != nil
    }

    var isDragging: Bool {
        phase == .dragging
    }

    var insertionIndicatorMinY: CGFloat? {
        guard phase == .dragging || phase == .settling,
              let sourceId = draggingEntryId,
              targetIndex != sourceIndex
        else { return nil }

        let geometry = projectedGeometry()
        let projected = TodayTodoReorderGeometry.projectedOrder(
            baseOrder: baseOrder,
            sourceId: sourceId,
            targetIndex: targetIndex
        )
        guard let targetId = projected[safe: targetIndex],
              let slotY = geometry.projectedMinY[targetId]
        else { return nil }
        return slotY - TodayTodoReorderMetrics.insertionIndicatorThickness / 2
    }

    func updateRowFrames(_ frames: [TodayTodoRowFrame]) {
        guard phase == .idle else { return }
        frozenRowFrames = Dictionary(uniqueKeysWithValues: frames.map { ($0.id, $0.frame) })
        frozenRowHeights = Dictionary(uniqueKeysWithValues: frames.map { ($0.id, $0.frame.height) })
        if let maxY = frames.map(\.frame.maxY).max() {
            listContentHeight = maxY
        }
    }

    func updateListViewportHeight(_ height: CGFloat) {
        listViewportHeight = max(height, 0)
    }

    func updateListRowSpacing(_ spacing: CGFloat) {
        listRowSpacing = spacing
    }

    func updateValidRegionInWindow(_ rect: CGRect) {
        validRegionInWindow = rect
    }

    func validateEntriesIdentity(_ entries: [TodayTodoEntry]) -> Bool {
        entries.map(\.id) == baseOrder
    }

    func beginPressing(entryId: UUID, entries: [TodayTodoEntry], event: NSEvent) {
        guard phase == .idle else { return }
        guard let index = entries.firstIndex(where: { $0.id == entryId }) else { return }
        guard updatePointer(from: event) else { return }

        draggingEntryId = entryId
        baseOrder = entries.map(\.id)
        sourceIndex = index
        targetIndex = index
        phase = .pressing
        bumpGeneration()
    }

    func beginDrag(entryId: UUID, entries: [TodayTodoEntry], event: NSEvent) {
        guard updatePointer(from: event) else { return }
        beginDrag(entryId: entryId, entries: entries, pointerContentY: pointerModel.contentY)
    }

    func beginDrag(entryId: UUID, entries: [TodayTodoEntry], pointerContentY: CGFloat) {
        if phase == .pressing, draggingEntryId == entryId {
            activateDragging(pointerContentY: pointerContentY)
            return
        }
        guard phase == .idle else { return }
        guard let index = entries.firstIndex(where: { $0.id == entryId }) else { return }

        draggingEntryId = entryId
        baseOrder = entries.map(\.id)
        sourceIndex = index
        targetIndex = index
        freezeRowSnapshots(from: entries)
        grabOffsetY = pointerContentY - (frozenRowFrames[entryId]?.minY ?? pointerContentY)
        phase = .dragging
        bumpGeneration()
        NSCursor.closedHand.set()
        startEscMonitor()
        recomputeTargetIndex()
    }

    func updateDrag(event: NSEvent, entries: [TodayTodoEntry]) {
        guard validateEntriesIdentity(entries) || phase == .idle else {
            cancelDrag()
            return
        }
        guard updatePointer(from: event) else { return }
        updateDrag(pointerContentY: pointerModel.contentY, viewportY: pointerModel.viewportY)
    }

    func updateDrag(pointerContentY: CGFloat, viewportY: CGFloat) {
        switch phase {
        case .pressing:
            activateDragging(pointerContentY: pointerContentY)
        case .dragging:
            if !isPointerInsideValidRegion(windowPoint: pointerModel.lastWindowPoint) {
                cancelDrag()
                return
            }
            pointerModel.update(
                contentY: pointerContentY,
                viewportY: clampedViewportY(viewportY),
                windowPoint: pointerModel.lastWindowPoint
            )
            objectWillChange.send()
            recomputeTargetIndex()
            updateEdgeScrollVelocity(viewportY: clampedViewportY(viewportY))
        case .idle, .settling, .cancelling:
            break
        }
    }

    func endDrag(commit: @escaping (UUID, Int) -> Void) {
        guard phase == .dragging else {
            if phase == .pressing {
                reset()
            }
            return
        }

        stopEscMonitor()
        NSCursor.arrow.set()
        edgeScrollVelocity = 0

        guard let sourceId = draggingEntryId else {
            reset()
            return
        }

        if targetIndex == sourceIndex {
            beginCancelling(commit: nil)
            return
        }

        beginSettling(sourceId: sourceId, commit: commit)
    }

    func cancelDrag() {
        guard phase == .dragging || phase == .pressing else { return }
        beginCancelling(commit: nil)
    }

    func invalidateSessionOnDisappear() {
        guard phase != .idle else { return }
        pendingCommit = nil
        completionGeneration &+= 1
        edgeScrollVelocity = 0
        reset()
    }

    func rowOffset(for entryId: UUID) -> CGFloat {
        guard let sourceId = draggingEntryId, entryId != sourceId else { return 0 }
        guard showsDragOverlay || phase == .settling || phase == .cancelling else { return 0 }

        let effectiveTarget = phase == .cancelling ? sourceIndex : targetIndex
        return TodayTodoReorderGeometry.rowOffset(
            entryId: entryId,
            sourceId: sourceId,
            sourceIndex: sourceIndex,
            targetIndex: effectiveTarget,
            baseOrder: baseOrder,
            rowFrames: frozenRowFrames,
            rowHeights: frozenRowHeights,
            listRowSpacing: listRowSpacing
        )
    }

    func draggedOverlayMinY(for entryId: UUID) -> CGFloat? {
        guard draggingEntryId == entryId else { return nil }

        switch phase {
        case .dragging:
            guard let frame = frozenRowFrames[entryId] else { return nil }
            return pointerModel.contentY - grabOffsetY
        case .settling:
            return settleOverlayMinY ?? projectedGeometry().projectedMinY[entryId]
        case .cancelling:
            return frozenRowFrames[entryId]?.minY
        case .pressing, .idle:
            return nil
        }
    }

    func finishSettlingAnimation() {
        guard phase == .settling || phase == .cancelling else { return }
        let generation = completionGeneration
        guard generation == sessionGeneration else { return }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if phase == .settling, let sourceId = draggingEntryId, let commit = pendingCommit {
                commit(sourceId, targetIndex)
            }
            pendingCommit = nil
            reset()
        }
    }

    func notifySettlingAnimationStarted() {
        completionGeneration = sessionGeneration
    }

    private func activateDragging(pointerContentY: CGFloat) {
        guard phase == .pressing, let entryId = draggingEntryId else { return }
        frozenRowHeights = Dictionary(
            uniqueKeysWithValues: frozenRowFrames.map { ($0.key, $0.value.height) }
        )
        grabOffsetY = pointerContentY - (frozenRowFrames[entryId]?.minY ?? pointerContentY)
        phase = .dragging
        bumpGeneration()
        NSCursor.closedHand.set()
        startEscMonitor()
        recomputeTargetIndex()
    }

    private func freezeRowSnapshots(from entries: [TodayTodoEntry]) {
        _ = entries
        frozenRowHeights = Dictionary(
            uniqueKeysWithValues: frozenRowFrames.map { ($0.key, $0.value.height) }
        )
    }

    private func projectedGeometry() -> TodayTodoProjectedGeometry {
        guard let sourceId = draggingEntryId else {
            return TodayTodoProjectedGeometry(projectedMinY: [:], totalHeight: 0)
        }
        return TodayTodoReorderGeometry.projectedGeometry(
            baseOrder: baseOrder,
            rowFrames: frozenRowFrames,
            rowHeights: frozenRowHeights,
            sourceId: sourceId,
            targetIndex: targetIndex,
            listRowSpacing: listRowSpacing
        )
    }

    private func recomputeTargetIndex() {
        guard let sourceId = draggingEntryId,
              let draggedHeight = frozenRowHeights[sourceId]
        else { return }

        let centerY = TodayTodoReorderGeometry.floatingCenterY(
            pointerContentY: pointerModel.contentY,
            grabOffsetY: grabOffsetY,
            draggedHeight: draggedHeight
        )
        let next = TodayTodoReorderGeometry.targetIndex(
            floatingCenterY: centerY,
            baseOrder: baseOrder,
            sourceId: sourceId,
            rowFrames: frozenRowFrames,
            previousTarget: targetIndex
        )
        if next != targetIndex {
            targetIndex = next
        }
    }

    private func beginSettling(sourceId: UUID, commit: @escaping (UUID, Int) -> Void) {
        let projectedY = projectedGeometry().projectedMinY[sourceId]
            ?? pointerModel.contentY - grabOffsetY
        settleOverlayMinY = projectedY
        pendingCommit = commit
        completionGeneration = sessionGeneration
        phase = .settling
    }

    private func beginCancelling(commit: ((UUID, Int) -> Void)?) {
        stopEscMonitor()
        NSCursor.arrow.set()
        edgeScrollVelocity = 0
        phase = .cancelling
        targetIndex = sourceIndex
        settleOverlayMinY = draggingEntryId.flatMap { frozenRowFrames[$0]?.minY }
        pendingCommit = commit
        completionGeneration = sessionGeneration
    }

    private func updateEdgeScrollVelocity(viewportY: CGFloat) {
        guard listViewportHeight > 0 else {
            edgeScrollVelocity = 0
            return
        }

        if viewportY < TodayTodoReorderMetrics.edgeScrollMargin {
            edgeScrollVelocity = -TodayTodoReorderMetrics.edgeScrollSpeed
        } else if viewportY > listViewportHeight - TodayTodoReorderMetrics.edgeScrollMargin {
            edgeScrollVelocity = TodayTodoReorderMetrics.edgeScrollSpeed
        } else {
            edgeScrollVelocity = 0
        }
    }

    private func clampedViewportY(_ viewportY: CGFloat) -> CGFloat {
        guard listViewportHeight > 0 else { return viewportY }
        return min(max(viewportY, 0), listViewportHeight)
    }

    private func isPointerInsideValidRegion(windowPoint: CGPoint) -> Bool {
        guard !validRegionInWindow.isNull else { return true }
        let expanded = validRegionInWindow.insetBy(
            dx: -TodayTodoReorderMetrics.reorderExitTolerance,
            dy: -TodayTodoReorderMetrics.reorderExitTolerance
        )
        return expanded.contains(windowPoint)
    }

    @discardableResult
    private func updatePointer(from event: NSEvent) -> Bool {
        guard let sample = listPointerView?.pointerSample(from: event) else { return false }
        pointerModel.update(
            contentY: sample.contentY,
            viewportY: sample.viewportY,
            windowPoint: sample.windowPoint
        )
        objectWillChange.send()
        return true
    }

    private func bumpGeneration() {
        sessionGeneration &+= 1
    }

    private func reset() {
        phase = .idle
        draggingEntryId = nil
        sourceIndex = 0
        targetIndex = 0
        baseOrder = []
        grabOffsetY = 0
        settleOverlayMinY = nil
        edgeScrollVelocity = 0
        pendingCommit = nil
        pointerModel.reset()
        stopEscMonitor()
        NSCursor.arrow.set()
        bumpGeneration()
    }

    private func startEscMonitor() {
        stopEscMonitor()
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            Task { @MainActor in
                self?.cancelDrag()
            }
            return nil
        }
    }

    private func stopEscMonitor() {
        if let escMonitor {
            NSEvent.removeMonitor(escMonitor)
            self.escMonitor = nil
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
