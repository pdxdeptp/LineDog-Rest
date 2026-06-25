import Foundation

/// Narrow action surface for the learning desk panel — avoids observing the full `AppViewModel`.
@MainActor
struct LearningDeskPanelEnvironment {
    let updateFocusSession: (UUID, Date, Date) -> Void
    let deleteFocusSession: (UUID) -> Void
    let updateFocusTimelineDay: (Date) -> Void
    let setTimelineVisible: (Bool) -> Void
    let enterTimelineHidden: () -> Void

    init(
        updateFocusSession: @escaping (UUID, Date, Date) -> Void,
        deleteFocusSession: @escaping (UUID) -> Void,
        updateFocusTimelineDay: @escaping (Date) -> Void,
        setTimelineVisible: @escaping (Bool) -> Void,
        enterTimelineHidden: @escaping () -> Void
    ) {
        self.updateFocusSession = updateFocusSession
        self.deleteFocusSession = deleteFocusSession
        self.updateFocusTimelineDay = updateFocusTimelineDay
        self.setTimelineVisible = setTimelineVisible
        self.enterTimelineHidden = enterTimelineHidden
    }

    init(appViewModel: AppViewModel) {
        self.init(
            updateFocusSession: { id, startedAt, endedAt in
                appViewModel.updateFocusSession(id: id, startedAt: startedAt, endedAt: endedAt)
            },
            deleteFocusSession: { id in
                appViewModel.deleteFocusSession(id: id)
            },
            updateFocusTimelineDay: { day in
                appViewModel.updateFocusTimelineDay(day)
            },
            setTimelineVisible: { visible in
                appViewModel.focusTimelinePresenter.setVisible(visible)
            },
            enterTimelineHidden: {
                appViewModel.focusTimelinePresenter.enterHidden()
            }
        )
    }
}
