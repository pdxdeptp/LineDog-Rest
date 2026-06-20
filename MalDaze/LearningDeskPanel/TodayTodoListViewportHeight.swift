import SwiftUI

private enum TodayTodoListViewportHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var todayTodoListViewportHeight: CGFloat {
        get { self[TodayTodoListViewportHeightKey.self] }
        set { self[TodayTodoListViewportHeightKey.self] = newValue }
    }
}
