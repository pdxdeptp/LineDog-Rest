import SwiftUI

struct LearningScheduleView<TaskRow: View>: View {
    let monthTitle: String
    let days: [HermesScheduleRangeDay]
    let deadlines: [HermesScheduleRangeDeadline]
    let budgetStudyMinutes: Int
    let isLoading: Bool
    let errorMessage: String?
    let truncated: Bool
    @Binding var selectedDate: String?
    let onPrevMonth: () -> Void
    let onNextMonth: () -> Void
    let onJumpToday: () -> Void
    @ViewBuilder let taskRow: (LearningTaskDisplayRow, Bool) -> TaskRow

    private var deadlineDates: Set<String> {
        Set(deadlines.map(\.deadline))
    }

    private var todayISO: String {
        LearningScheduleFormatting.isoDate(Date())
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("加载日程…")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(8)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    monthHeader
                    if truncated {
                        Text("范围已截断，部分远日任务可能未显示。")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    agendaList
                }
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

    private var agendaList: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(days) { day in
                        agendaSection(day)
                            .id(day.date)
                    }
                }
            }
            .onChange(of: selectedDate) { newValue in
                guard let newValue else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(newValue, anchor: .top)
                }
            }
            .onAppear {
                guard selectedDate == nil else { return }
                if days.contains(where: { $0.date == todayISO }) {
                    selectedDate = todayISO
                } else if let first = days.first(where: { !$0.tasks.isEmpty }) {
                    selectedDate = first.date
                }
            }
        }
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
