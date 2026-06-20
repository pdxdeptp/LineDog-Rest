import AppKit
import Combine
import SwiftUI

enum TodayTodoReorderMetrics {
    static let longPressDuration: TimeInterval = 0.35
    static let dragStartThreshold: CGFloat = 4
    static let insertionGap: CGFloat = 2
    static let springResponse: Double = 0.32
    static let springDamping: Double = 0.86
    static let edgeScrollMargin: CGFloat = 8
    static let settlingDuration: TimeInterval = springResponse + 0.08
    static let liftScale: CGFloat = 1.02
}

enum TodayTodoReorderPhase: Equatable {
    case idle
    case pressing
    case dragging
    case settling
    case cancelling
}

@MainActor
final class TodayTodoReorderController: ObservableObject {
    @Published private(set) var phase: TodayTodoReorderPhase = .idle
    @Published private(set) var draggingEntryId: UUID?
    @Published private(set) var sourceIndex: Int = 0
    @Published private(set) var insertionIndex: Int = 0
    @Published private(set) var previewOrder: [UUID] = []
    @Published private(set) var listPointerY: CGFloat = 0
    @Published private(set) var frozenRowFrames: [UUID: CGRect] = [:]
    @Published private(set) var edgeScrollDirection: CGFloat = 0
    @Published private(set) var edgeScrollTargetId: UUID?

    private var liveRowFrames: [UUID: CGRect] = [:]
    private var frozenRowHeights: [UUID: CGFloat] = [:]
    private var grabOffsetY: CGFloat = 0
    private var listViewportHeight: CGFloat = 0
    private var settleWorkItem: DispatchWorkItem?
    private var escMonitor: Any?

    weak var listPointerView: TodayTodoListPointerView?

    var springAnimation: Animation {
        .spring(
            response: TodayTodoReorderMetrics.springResponse,
            dampingFraction: TodayTodoReorderMetrics.springDamping
        )
    }

    var showsDragOverlay: Bool {
        switch phase {
        case .pressing, .dragging, .settling, .cancelling:
            return draggingEntryId != nil
        case .idle:
            return false
        }
    }

    var isDragging: Bool {
        phase == .dragging
    }

    func updateRowFrames(_ frames: [TodayTodoRowFrame]) {
        liveRowFrames = Dictionary(uniqueKeysWithValues: frames.map { ($0.id, $0.frame) })
        guard phase == .idle else { return }
    }

    func updateListViewportHeight(_ height: CGFloat) {
        listViewportHeight = max(height, 0)
    }

    func beginPressing(entryId: UUID, entries: [TodayTodoEntry], event: NSEvent) {
        guard let pointerY = pointerY(from: event) else { return }
        beginPressing(entryId: entryId, entries: entries, pointerY: pointerY)
    }

    func beginPressing(entryId: UUID, entries: [TodayTodoEntry], pointerY: CGFloat) {
        guard phase == .idle else { return }
        guard entries.contains(where: { $0.id == entryId }) else { return }

        draggingEntryId = entryId
        previewOrder = entries.map(\.id)
        sourceIndex = previewOrder.firstIndex(of: entryId) ?? 0
        insertionIndex = sourceIndex
        listPointerY = pointerY
        phase = .pressing
    }

    func beginDrag(entryId: UUID, entries: [TodayTodoEntry], pointerY: CGFloat) {
        if phase == .pressing, draggingEntryId == entryId {
            activateDragging(pointerY: pointerY)
            return
        }
        guard phase == .idle else { return }
        guard let index = entries.firstIndex(where: { $0.id == entryId }) else { return }

        draggingEntryId = entryId
        previewOrder = entries.map(\.id)
        sourceIndex = index
        insertionIndex = index
        listPointerY = pointerY
        freezeRowSnapshots()
        grabOffsetY = pointerY - (frozenRowFrames[entryId]?.minY ?? pointerY)
        phase = .dragging
        NSCursor.closedHand.set()
        startEscMonitor()
    }

    func beginDrag(entryId: UUID, entries: [TodayTodoEntry], event: NSEvent) {
        guard let pointerY = pointerY(from: event) else { return }
        beginDrag(entryId: entryId, entries: entries, pointerY: pointerY)
    }

    func updateDrag(event: NSEvent, entries: [TodayTodoEntry]) {
        guard let pointerY = pointerY(from: event) else { return }
        updateDrag(pointerY: pointerY, entries: entries)
    }

    func updateDrag(pointerY: CGFloat, entries: [TodayTodoEntry]) {
        switch phase {
        case .pressing:
            listPointerY = pointerY
            activateDragging(pointerY: pointerY)
        case .dragging:
            listPointerY = pointerY
            let nextInsertion = Self.insertionIndex(
                for: pointerY,
                order: previewOrder,
                rowFrames: frozenRowFrames
            )
            if nextInsertion != insertionIndex {
                insertionIndex = nextInsertion
                applyInsertionToPreviewOrder()
            }
            updateEdgeScroll(pointerY: pointerY)
        case .idle, .settling, .cancelling:
            break
        }
    }

    func endDrag(commit: @escaping (Int, Int) -> Void) {
        guard phase == .dragging || phase == .pressing else { return }

        let src = sourceIndex
        let ins = insertionIndex
        stopEscMonitor()
        NSCursor.arrow.set()

        guard src != ins, ins != src + 1 else {
            reset()
            return
        }

        phase = .settling
        edgeScrollDirection = 0
        edgeScrollTargetId = nil
        schedulePhaseCompletion {
            commit(src, ins)
            self.reset()
        }
    }

    func cancelDrag() {
        guard phase == .dragging || phase == .pressing else { return }

        stopEscMonitor()
        NSCursor.arrow.set()
        phase = .cancelling
        edgeScrollDirection = 0
        edgeScrollTargetId = nil
        previewOrder = restoreSourceOrder()
        insertionIndex = sourceIndex
        schedulePhaseCompletion {
            self.reset()
        }
    }

    func rowOffset(for entryId: UUID, listRowSpacing: CGFloat) -> CGFloat {
        guard showsDragOverlay,
              let draggingEntryId,
              draggingEntryId != entryId,
              let draggedFrame = frozenRowFrames[draggingEntryId],
              let dragIndex = previewOrder.firstIndex(of: draggingEntryId),
              let rowIndex = previewOrder.firstIndex(of: entryId)
        else { return 0 }

        let shift = draggedFrame.height + listRowSpacing + TodayTodoReorderMetrics.insertionGap

        if dragIndex < insertionIndex {
            if rowIndex > dragIndex, rowIndex < insertionIndex {
                return -shift
            }
        } else if dragIndex >= insertionIndex {
            if rowIndex >= insertionIndex, rowIndex < dragIndex {
                return shift
            }
        }
        return 0
    }

    func draggedOverlayOffset(for entryId: UUID) -> CGFloat {
        guard draggingEntryId == entryId else { return 0 }

        switch phase {
        case .dragging:
            guard let frame = frozenRowFrames[entryId] else { return 0 }
            return listPointerY - grabOffsetY - frame.minY
        case .settling, .cancelling, .pressing:
            return 0
        case .idle:
            return 0
        }
    }

    func overlayScale(for entryId: UUID) -> CGFloat {
        guard draggingEntryId == entryId else { return 1 }
        switch phase {
        case .pressing, .dragging, .settling:
            return TodayTodoReorderMetrics.liftScale
        case .cancelling, .idle:
            return 1
        }
    }

    private func activateDragging(pointerY: CGFloat) {
        guard phase == .pressing, let entryId = draggingEntryId else { return }
        listPointerY = pointerY
        freezeRowSnapshots()
        grabOffsetY = pointerY - (frozenRowFrames[entryId]?.minY ?? pointerY)
        phase = .dragging
        NSCursor.closedHand.set()
        startEscMonitor()
    }

    private func freezeRowSnapshots() {
        frozenRowFrames = liveRowFrames
        frozenRowHeights = Dictionary(
            uniqueKeysWithValues: liveRowFrames.map { ($0.key, $0.value.height) }
        )
    }

    private func applyInsertionToPreviewOrder() {
        guard let entryId = draggingEntryId,
              let from = previewOrder.firstIndex(of: entryId)
        else { return }

        let target = insertionIndex
        if target == from || target == from + 1 { return }

        var order = previewOrder
        order.remove(at: from)
        let insertAt = target > from ? target - 1 : target
        order.insert(entryId, at: insertAt)

        withAnimation(springAnimation) {
            previewOrder = order
        }
    }

    private func restoreSourceOrder() -> [UUID] {
        guard let entryId = draggingEntryId else { return previewOrder }
        var order = previewOrder
        guard let current = order.firstIndex(of: entryId) else { return order }
        order.remove(at: current)
        order.insert(entryId, at: min(max(sourceIndex, 0), order.count))
        return order
    }

    private func updateEdgeScroll(pointerY: CGFloat) {
        guard listViewportHeight > 0 else {
            edgeScrollDirection = 0
            edgeScrollTargetId = nil
            return
        }

        if pointerY < TodayTodoReorderMetrics.edgeScrollMargin {
            edgeScrollDirection = -1
        } else if pointerY > listViewportHeight - TodayTodoReorderMetrics.edgeScrollMargin {
            edgeScrollDirection = 1
        } else {
            edgeScrollDirection = 0
            edgeScrollTargetId = nil
            return
        }

        edgeScrollTargetId = nearestScrollTargetId(for: edgeScrollDirection)
    }

    func nearestScrollTargetId(for direction: CGFloat) -> UUID? {
        let candidates = previewOrder.filter { $0 != draggingEntryId }
        guard !candidates.isEmpty else { return nil }

        if direction < 0 {
            return candidates.min {
                (frozenRowFrames[$0]?.minY ?? .greatestFiniteMagnitude)
                    < (frozenRowFrames[$1]?.minY ?? .greatestFiniteMagnitude)
            }
        }

        return candidates.max {
            (frozenRowFrames[$0]?.maxY ?? -.greatestFiniteMagnitude)
                < (frozenRowFrames[$1]?.maxY ?? -.greatestFiniteMagnitude)
        }
    }

    private func pointerY(from event: NSEvent) -> CGFloat? {
        listPointerView?.listPointerY(from: event)
    }

    private func schedulePhaseCompletion(_ completion: @escaping () -> Void) {
        settleWorkItem?.cancel()
        let work = DispatchWorkItem { completion() }
        settleWorkItem = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + TodayTodoReorderMetrics.settlingDuration,
            execute: work
        )
    }

    private func reset() {
        settleWorkItem?.cancel()
        settleWorkItem = nil
        phase = .idle
        draggingEntryId = nil
        sourceIndex = 0
        insertionIndex = 0
        previewOrder = []
        listPointerY = 0
        grabOffsetY = 0
        frozenRowFrames = [:]
        frozenRowHeights = [:]
        edgeScrollDirection = 0
        edgeScrollTargetId = nil
        stopEscMonitor()
        NSCursor.arrow.set()
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

    static func insertionIndex(
        for pointerY: CGFloat,
        order: [UUID],
        rowFrames: [UUID: CGRect]
    ) -> Int {
        for (index, entryId) in order.enumerated() {
            guard let frame = rowFrames[entryId] else { continue }
            if pointerY < frame.midY {
                return index
            }
        }
        return order.count
    }
}

enum TodayTodoReorderPointerBridge {
    static func listPointerY(appKitLocalY: CGFloat, listHeight: CGFloat) -> CGFloat {
        listHeight - appKitLocalY
    }
}
