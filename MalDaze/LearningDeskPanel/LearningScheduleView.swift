import SwiftUI

struct LearningScheduleView<TaskRow: View>: View {
    let monthTitle: String
    let days: [HermesScheduleRangeDay]
    let deadlines: [HermesScheduleRangeDeadline]
    let budgetStudyMinutes: Int
    let isLoading: Bool
    let isFetching: Bool
    let errorMessage: String?
    let truncated: Bool
    let hiddenEarlierDayCount: Int
    @Binding var selectedDate: String?
    let onPrevMonth: () -> Void
    let onNextMonth: () -> Void
    let onJumpToday: () -> Void
    let onShowEarlierDays: () -> Void
    @ViewBuilder let taskRow: (LearningTaskDisplayRow, Bool) -> TaskRow

    @State private var chromeHeight: CGFloat = 0

    private var deadlineDates: Set<String> {
        Set(deadlines.map(\.deadline))
    }

    private var todayISO: String {
        LearningScheduleFormatting.isoDate(Date())
    }

    private var showsEarlierDaysButton: Bool {
        hiddenEarlierDayCount > 0
    }

    var body: some View {
        GeometryReader { geometry in
            let viewportHeight = LearningScheduleScrollLayout.agendaViewportHeight(
                totalHeight: geometry.size.height,
                chromeHeight: chromeHeight,
                showsEarlierButton: showsEarlierDaysButton
            )

            VStack(alignment: .leading, spacing: LearningScheduleScrollLayout.chromeSpacing) {
                scheduleChrome
                    .background {
                        GeometryReader { chromeGeometry in
                            Color.clear.preference(
                                key: ScheduleChromeHeightKey.self,
                                value: chromeGeometry.size.height
                            )
                        }
                    }

                if let errorMessage, days.isEmpty, !isLoading {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(8)
                    Spacer(minLength: 0)
                } else {
                    agendaList(viewportHeight: viewportHeight)
                        .frame(height: viewportHeight, alignment: .topLeading)
                        .overlay {
                            if isLoading {
                                ProgressView("加载日程…")
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(Color(.controlBackgroundColor).opacity(0.72))
                            } else if isFetching {
                                ProgressView()
                                    .controlSize(.small)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                    .padding(8)
                            }
                        }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .onPreferenceChange(ScheduleChromeHeightKey.self) { chromeHeight = $0 }
        }
    }

    private var scheduleChrome: some View {
        VStack(alignment: .leading, spacing: LearningScheduleScrollLayout.chromeSpacing) {
            monthHeader
            if truncated {
                Text("范围已截断，部分远日任务可能未显示。")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            if showsEarlierDaysButton {
                Button {
                    onShowEarlierDays()
                } label: {
                    Label("显示较早 \(hiddenEarlierDayCount) 天", systemImage: "chevron.up")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private var monthHeader: some View {
        HStack(spacing: 8) {
            Button(action: onPrevMonth) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)
            Text(monthTitle)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
            Button("今天", action: onJumpToday)
                .buttonStyle(.borderless)
                .font(.caption)
            Button(action: onNextMonth) {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)
        }
    }

    @ViewBuilder
    private func agendaList(viewportHeight: CGFloat) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(days) { day in
                    agendaSection(day)
                        .id(day.date)
                }
            }
        }
        .frame(height: viewportHeight, alignment: .topLeading)
    }

    @ViewBuilder
    private func agendaSection(_ day: HermesScheduleRangeDay) -> some View {
        let isToday = day.date == todayISO
        let overflowCount = day.tasks.filter(\.afterProjectDeadline).count

        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(LearningScheduleFormatting.dayTitle(day.date))
                    .font(.caption.weight(.semibold).monospacedDigit())
                if isToday {
                    Text("今天")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                }
                if day.isRestDay {
                    Text("休息")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                } else if !day.tasks.isEmpty {
                    Text("\(day.tasks.count) 节")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(LearningCapacityFormatting.formatLoad(
                        totalMinutes: day.studyMinutes,
                        budgetMinutes: budgetStudyMinutes
                    ))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(day.overCapacity ? .red : .primary)
                    if day.overCapacity {
                        Text("超额")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.red)
                    }
                }
                if deadlineDates.contains(day.date) {
                    Text("截止")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                }
                if overflowCount > 0 {
                    Text("超期 \(overflowCount)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                }
                Spacer(minLength: 0)
            }

            if day.isRestDay {
                Text("休息日")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else if day.tasks.isEmpty {
                Text("无待办")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(Array(day.tasks.enumerated()), id: \.element.id) { index, task in
                    let row = task.displayRow(scheduledDate: day.date, index: index + 1)
                    taskRow(row, task.isReview)
                    if task.afterProjectDeadline {
                        Text("排期晚于项目截止日")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .padding(.leading, 28)
                    }
                }
            }
        }
        .padding(8)
        .background(
            (isToday || selectedDate == day.date)
                ? Color.accentColor.opacity(0.08)
                : Color(.controlBackgroundColor).opacity(0.35),
            in: RoundedRectangle(cornerRadius: 8)
        )
    }
}

private struct ScheduleChromeHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

enum LearningScheduleFormatting {
    static func isoDate(_ date: Date) -> String {
        let cal = Calendar.current
        let y = cal.component(.year, from: date)
        let m = cal.component(.month, from: date)
        let d = cal.component(.day, from: date)
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    static func dayTitle(_ iso: String) -> String {
        guard let date = LearningDeadlineEmphasis.parseISO(iso) else { return iso }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M/d EEE"
        return formatter.string(from: date)
    }
}
