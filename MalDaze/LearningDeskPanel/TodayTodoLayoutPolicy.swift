import CoreGraphics

enum TodayTodoLayoutMode: Equatable {
    case measuring
    case compact
    case pinned
}

struct TodayTodoLayoutResolution: Equatable {
    let mode: TodayTodoLayoutMode
    let listViewportHeight: CGFloat
    let listScrollEnabled: Bool
}

/// 今日 todo compact/pinned 布局解析（纯函数，可单测）。
enum TodayTodoLayoutPolicy {
    static let layoutTolerance: CGFloat = 0.5
    static let draftRowFallbackHeight: CGFloat = 28
    static let listRowSpacing: CGFloat = 2

    static func resolve(
        listHeight: CGFloat?,
        draftRowHeight: CGFloat?,
        draftMinimumHeight: CGFloat,
        measuredListWidth: CGFloat?,
        liveWidth: CGFloat,
        availableHeight: CGFloat,
        listRowSpacing: CGFloat = TodayTodoLayoutPolicy.listRowSpacing,
        tolerance: CGFloat = TodayTodoLayoutPolicy.layoutTolerance
    ) -> TodayTodoLayoutResolution {
        let safeAvailable = max(sanitized(availableHeight) ?? 0, 0)
        let safeDraft = max(
            sanitized(draftRowHeight) ?? 0,
            sanitized(draftMinimumHeight) ?? 0,
            draftRowFallbackHeight
        )
        let capacity = max(safeAvailable - safeDraft - max(sanitized(listRowSpacing) ?? 0, 0), 0)
        let fitCapacity = max(capacity - tolerance, 0)

        let widthMatches: Bool = {
            guard let measuredWidth = sanitized(measuredListWidth) else { return false }
            let live = sanitized(liveWidth) ?? 0
            return abs(measuredWidth - live) <= tolerance
        }()

        guard let list = sanitized(listHeight),
              let draft = sanitized(draftRowHeight), draft > 0,
              widthMatches
        else {
            return TodayTodoLayoutResolution(
                mode: .measuring,
                listViewportHeight: capacity,
                listScrollEnabled: false
            )
        }

        if list <= fitCapacity {
            return TodayTodoLayoutResolution(
                mode: .compact,
                listViewportHeight: min(list, capacity),
                listScrollEnabled: false
            )
        }

        return TodayTodoLayoutResolution(
            mode: .pinned,
            listViewportHeight: capacity,
            listScrollEnabled: capacity > 0 && list > 0
        )
    }

    private static func sanitized(_ value: CGFloat?) -> CGFloat? {
        guard let value, value.isFinite else { return nil }
        return max(value, 0)
    }
}
