import Combine
import SwiftUI

@MainActor
final class TodayTodoDragPointerModel: ObservableObject {
    @Published private(set) var contentY: CGFloat = 0
    @Published private(set) var viewportY: CGFloat = 0
    @Published private(set) var lastWindowPoint: CGPoint = .zero

    func update(contentY: CGFloat, viewportY: CGFloat, windowPoint: CGPoint) {
        self.contentY = contentY
        self.viewportY = viewportY
        self.lastWindowPoint = windowPoint
    }

    func reset() {
        contentY = 0
        viewportY = 0
        lastWindowPoint = .zero
    }
}
