import SwiftUI

struct LearningDeskFocusTimelineRow: View {
    @ObservedObject var presenter: FocusTimelinePresenter
    let responseDate: String
    let onUpdateSession: (UUID, Date, Date) -> Void
    let onDeleteSession: (UUID) -> Void

    var body: some View {
        FocusDayTimelineCellGridView(
            model: presenter.displayModel,
            sessionCount: presenter.sessionCount,
            totalMinutes: presenter.totalMinutes,
            hasActivity: presenter.hasActivity,
            onUpdateSession: onUpdateSession,
            onDeleteSession: onDeleteSession
        )
        .onAppear { presenter.setVisible(true) }
        .onDisappear { presenter.setVisible(false) }
    }
}
