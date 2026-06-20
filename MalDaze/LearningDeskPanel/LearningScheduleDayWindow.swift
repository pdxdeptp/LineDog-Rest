import Foundation

/// 日程列表从哪一天开始展示（不依赖 ScrollView.scrollTo）。
enum LearningScheduleDayWindow: Equatable {
    case entireRange
    case startingAt(String)

    struct Presentation: Equatable {
        let visibleDays: [HermesScheduleRangeDay]
        let hiddenEarlierDayCount: Int
    }

    func presentation(for days: [HermesScheduleRangeDay]) -> Presentation {
        guard case .startingAt(let anchor) = self else {
            return Presentation(visibleDays: days, hiddenEarlierDayCount: 0)
        }
        guard let index = days.firstIndex(where: { $0.date >= anchor }) else {
            return Presentation(visibleDays: days, hiddenEarlierDayCount: 0)
        }
        return Presentation(
            visibleDays: Array(days[index...]),
            hiddenEarlierDayCount: index
        )
    }
}

enum LearningScheduleScrollLayout {
    static let chromeSpacing: CGFloat = 10
    static let earlierButtonBlockHeight: CGFloat = 30

    static func agendaViewportHeight(
        totalHeight: CGFloat,
        chromeHeight: CGFloat,
        showsEarlierButton: Bool
    ) -> CGFloat {
        let chrome = chromeHeight
            + (showsEarlierButton ? earlierButtonBlockHeight + chromeSpacing : 0)
        return max(0, totalHeight - chrome)
    }
}
