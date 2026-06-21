import CoreGraphics
import Foundation

enum TodayTodoReorderMetrics {
    static let longPressDuration: TimeInterval = 0.35
    static let dragStartThreshold: CGFloat = 4
    static let targetHysteresis: CGFloat = 2
    static let insertionIndicatorThickness: CGFloat = 2
    static let reorderExitTolerance: CGFloat = 12
    static let springResponse: Double = 0.32
    static let springDamping: Double = 0.86
    static let edgeScrollMargin: CGFloat = 8
    static let edgeScrollSpeed: CGFloat = 120
    static let liftScale: CGFloat = 1.02
}

enum TodayTodoReorderPhase: Equatable {
    case idle
    case pressing
    case dragging
    case settling
    case cancelling
}

struct TodayTodoProjectedGeometry: Equatable {
    let projectedMinY: [UUID: CGFloat]
    let totalHeight: CGFloat
}

enum TodayTodoReorderGeometry {
    static func projectedOrder(
        baseOrder: [UUID],
        sourceId: UUID,
        targetIndex: Int
    ) -> [UUID] {
        guard let from = baseOrder.firstIndex(of: sourceId) else { return baseOrder }
        var order = baseOrder
        order.remove(at: from)
        let insertAt = min(max(targetIndex, 0), order.count)
        order.insert(sourceId, at: insertAt)
        return order
    }

    static func projectedGeometry(
        baseOrder: [UUID],
        rowFrames: [UUID: CGRect],
        rowHeights: [UUID: CGFloat],
        sourceId: UUID,
        targetIndex: Int,
        listRowSpacing: CGFloat
    ) -> TodayTodoProjectedGeometry {
        let projected = projectedOrder(
            baseOrder: baseOrder,
            sourceId: sourceId,
            targetIndex: targetIndex
        )
        let startY = baseOrder.compactMap { rowFrames[$0]?.minY }.min() ?? 0
        var currentY = startY
        var minY: [UUID: CGFloat] = [:]

        for id in projected {
            minY[id] = currentY
            let height = rowHeights[id] ?? rowFrames[id]?.height ?? 0
            currentY += height + listRowSpacing
        }

        let totalHeight = max(currentY - listRowSpacing - startY, 0)
        return TodayTodoProjectedGeometry(projectedMinY: minY, totalHeight: totalHeight)
    }

    static func rowOffset(
        entryId: UUID,
        sourceId: UUID,
        sourceIndex: Int,
        targetIndex: Int,
        baseOrder: [UUID],
        rowFrames: [UUID: CGRect],
        rowHeights: [UUID: CGFloat],
        listRowSpacing: CGFloat
    ) -> CGFloat {
        guard entryId != sourceId, targetIndex != sourceIndex else { return 0 }

        let projected = projectedGeometry(
            baseOrder: baseOrder,
            rowFrames: rowFrames,
            rowHeights: rowHeights,
            sourceId: sourceId,
            targetIndex: targetIndex,
            listRowSpacing: listRowSpacing
        )
        guard let frozen = rowFrames[entryId]?.minY,
              let target = projected.projectedMinY[entryId]
        else { return 0 }
        return target - frozen
    }

    static func rawTargetIndex(
        floatingCenterY: CGFloat,
        baseOrder: [UUID],
        sourceId: UUID,
        rowFrames: [UUID: CGRect]
    ) -> Int {
        let candidates = baseOrder.filter { $0 != sourceId }
        for (index, id) in candidates.enumerated() {
            guard let frame = rowFrames[id] else { continue }
            if floatingCenterY < frame.midY {
                return index
            }
        }
        return candidates.count
    }

    static func targetIndex(
        floatingCenterY: CGFloat,
        baseOrder: [UUID],
        sourceId: UUID,
        rowFrames: [UUID: CGRect],
        previousTarget: Int,
        hysteresis: CGFloat = TodayTodoReorderMetrics.targetHysteresis
    ) -> Int {
        let candidates = baseOrder.filter { $0 != sourceId }
        guard !candidates.isEmpty else { return 0 }

        var raw = rawTargetIndex(
            floatingCenterY: floatingCenterY,
            baseOrder: baseOrder,
            sourceId: sourceId,
            rowFrames: rowFrames
        )
        raw = min(max(raw, 0), baseOrder.count - 1)

        guard previousTarget >= 0, previousTarget < baseOrder.count else { return raw }
        guard raw != previousTarget else { return previousTarget }

        if raw > previousTarget {
            guard let boundaryId = candidates[safe: previousTarget],
                  let frame = rowFrames[boundaryId]
            else { return raw }
            if floatingCenterY < frame.midY + hysteresis {
                return previousTarget
            }
        } else if raw < previousTarget {
            let boundaryIndex = previousTarget - 1
            guard boundaryIndex >= 0, let boundaryId = candidates[safe: boundaryIndex],
                  let frame = rowFrames[boundaryId]
            else { return raw }
            if floatingCenterY > frame.midY - hysteresis {
                return previousTarget
            }
        }

        return raw
    }

    static func floatingCenterY(
        pointerContentY: CGFloat,
        grabOffsetY: CGFloat,
        draggedHeight: CGFloat
    ) -> CGFloat {
        pointerContentY - grabOffsetY + draggedHeight / 2
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

enum TodayTodoReorderPointerBridge {
    static func listPointerY(appKitLocalY: CGFloat, listHeight: CGFloat) -> CGFloat {
        listHeight - appKitLocalY
    }
}
