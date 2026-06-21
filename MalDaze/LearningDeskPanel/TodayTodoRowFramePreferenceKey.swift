import CoreGraphics
import SwiftUI

struct TodayTodoRowFrame: Equatable {
    let id: UUID
    let frame: CGRect
}

struct TodayTodoRowFramePreferenceKey: PreferenceKey {
    static let defaultValue: [TodayTodoRowFrame] = []

    static func reduce(value: inout [TodayTodoRowFrame], nextValue: () -> [TodayTodoRowFrame]) {
        value.append(contentsOf: nextValue())
    }
}

struct TodayTodoReorderEdgeScrollPreference: Equatable {
    var velocity: CGFloat = 0
    var enabled: Bool = false
}

struct TodayTodoReorderEdgeScrollPreferenceKey: PreferenceKey {
    static let defaultValue = TodayTodoReorderEdgeScrollPreference()

    static func reduce(value: inout TodayTodoReorderEdgeScrollPreference, nextValue: () -> TodayTodoReorderEdgeScrollPreference) {
        value = nextValue()
    }
}

struct TodayTodoReorderEdgeScrollKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct TodayTodoRowFrameReporter: ViewModifier {
    let entryId: UUID
    let coordinateSpace: CoordinateSpace

    func body(content: Content) -> some View {
        content.background {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: TodayTodoRowFramePreferenceKey.self,
                    value: [
                        TodayTodoRowFrame(
                            id: entryId,
                            frame: geometry.frame(in: coordinateSpace)
                        )
                    ]
                )
            }
        }
    }
}

extension View {
    func todayTodoRowFrame(id: UUID, in coordinateSpace: CoordinateSpace) -> some View {
        modifier(TodayTodoRowFrameReporter(entryId: id, coordinateSpace: coordinateSpace))
    }
}
