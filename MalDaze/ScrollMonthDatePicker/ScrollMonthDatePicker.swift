import SwiftUI

enum ScrollMonthDatePickerLogic {
    static let monthRadius = 12
    static let visibleHeight: CGFloat = 220
    static let popoverWidth: CGFloat = 320
    static let weekdaySymbols = ["日", "一", "二", "三", "四", "五", "六"]

    struct DayCell: Equatable, Identifiable {
        let id: String
        let date: Date
        let dayNumber: Int
        let isInDisplayedMonth: Bool
    }

    static func pickerCalendar(_ base: Calendar = .current) -> Calendar {
        var calendar = base
        calendar.firstWeekday = 1
        calendar.locale = Locale(identifier: "zh_CN")
        return calendar
    }

    static func monthKey(for date: Date, calendar: Calendar) -> String {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        return String(format: "%04d-%02d", year, month)
    }

    static func firstDayOfMonth(containing date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    static func monthStarts(around anchor: Date, radius: Int, calendar: Calendar) -> [Date] {
        let first = firstDayOfMonth(containing: anchor, calendar: calendar)
        return (-radius...radius).compactMap { offset in
            calendar.date(byAdding: .month, value: offset, to: first)
        }
    }

    static func monthTitle(for monthStart: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy 年 M 月"
        return formatter.string(from: monthStart)
    }

    static func normalizedSelection(_ date: Date, calendar: Calendar) -> Date {
        calendar.startOfDay(for: date)
    }

    static func isoDate(_ date: Date, calendar: Calendar) -> String {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func mergeCalendarDay(from daySource: Date, preservingTimeFrom timeSource: Date, calendar: Calendar) -> Date {
        let day = calendar.dateComponents([.year, .month, .day], from: daySource)
        let time = calendar.dateComponents([.hour, .minute, .second], from: timeSource)
        var merged = DateComponents()
        merged.year = day.year
        merged.month = day.month
        merged.day = day.day
        merged.hour = time.hour
        merged.minute = time.minute
        merged.second = time.second
        return calendar.date(from: merged) ?? daySource
    }

    static func dayGrid(for monthStart: Date, calendar: Calendar) -> [DayCell] {
        let displayedYear = calendar.component(.year, from: monthStart)
        let displayedMonth = calendar.component(.month, from: monthStart)
        guard let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }

        let leading = leadingBlankCount(for: monthStart, calendar: calendar)
        var cells: [DayCell] = []

        if leading > 0,
           let previousMonth = calendar.date(byAdding: .month, value: -1, to: monthStart),
           let previousDayCount = calendar.range(of: .day, in: .month, for: previousMonth)?.count {
            let previousYear = calendar.component(.year, from: previousMonth)
            let previousMonthValue = calendar.component(.month, from: previousMonth)
            for offset in 0..<leading {
                let day = previousDayCount - leading + offset + 1
                let date = dateComponents(
                    year: previousYear,
                    month: previousMonthValue,
                    day: day,
                    calendar: calendar
                )
                cells.append(makeCell(
                    date: date,
                    dayNumber: day,
                    inDisplayedMonth: false,
                    calendar: calendar
                ))
            }
        }

        for day in dayRange {
            let date = dateComponents(
                year: displayedYear,
                month: displayedMonth,
                day: day,
                calendar: calendar
            )
            cells.append(makeCell(
                date: date,
                dayNumber: day,
                inDisplayedMonth: true,
                calendar: calendar
            ))
        }

        let trailing = (7 - (cells.count % 7)) % 7
        if trailing > 0,
           let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) {
            let nextYear = calendar.component(.year, from: nextMonth)
            let nextMonthValue = calendar.component(.month, from: nextMonth)
            for day in 1...trailing {
                let date = dateComponents(
                    year: nextYear,
                    month: nextMonthValue,
                    day: day,
                    calendar: calendar
                )
                cells.append(makeCell(
                    date: date,
                    dayNumber: day,
                    inDisplayedMonth: false,
                    calendar: calendar
                ))
            }
        }

        return cells
    }

    private static func leadingBlankCount(for monthStart: Date, calendar: Calendar) -> Int {
        let weekday = calendar.component(.weekday, from: monthStart)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private static func dateComponents(
        year: Int,
        month: Int,
        day: Int,
        calendar: Calendar
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components) ?? monthStartFallback(year: year, month: month, calendar: calendar)
    }

    private static func monthStartFallback(year: Int, month: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
    }

    private static func makeCell(
        date: Date,
        dayNumber: Int,
        inDisplayedMonth: Bool,
        calendar: Calendar
    ) -> DayCell {
        DayCell(
            id: isoDate(date, calendar: calendar),
            date: date,
            dayNumber: dayNumber,
            isInDisplayedMonth: inDisplayedMonth
        )
    }
}

struct ScrollMonthDatePicker: View {
    @Binding var selection: Date
    var accessibilityLabel: String = "选择日期"
    var onSelect: ((Date) -> Void)?
    var onDoublePick: ((Date) -> Void)?

    private let calendar = ScrollMonthDatePickerLogic.pickerCalendar()

    var body: some View {
        let months = ScrollMonthDatePickerLogic.monthStarts(
            around: selection,
            radius: ScrollMonthDatePickerLogic.monthRadius,
            calendar: calendar
        )
        let selectedMonthID = ScrollMonthDatePickerLogic.monthKey(for: selection, calendar: calendar)

        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(months, id: \.self) { monthStart in
                        monthSection(monthStart)
                            .id(ScrollMonthDatePickerLogic.monthKey(for: monthStart, calendar: calendar))
                    }
                }
            }
            .onAppear {
                proxy.scrollTo(selectedMonthID, anchor: .top)
            }
        }
        .frame(height: ScrollMonthDatePickerLogic.visibleHeight)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private func monthSection(_ monthStart: Date) -> some View {
        VStack(spacing: 8) {
            Text(ScrollMonthDatePickerLogic.monthTitle(for: monthStart, calendar: calendar))
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7),
                spacing: 2
            ) {
                ForEach(ScrollMonthDatePickerLogic.weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(ScrollMonthDatePickerLogic.dayGrid(for: monthStart, calendar: calendar)) { cell in
                    dayButton(cell)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func dayButton(_ cell: ScrollMonthDatePickerLogic.DayCell) -> some View {
        let isSelected = calendar.isDate(cell.date, inSameDayAs: selection)
        let isToday = calendar.isDateInToday(cell.date)

        Button {
            applySelection(from: cell)
        } label: {
            Text("\(cell.dayNumber)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(dayForeground(isSelected: isSelected, cell: cell))
                .frame(maxWidth: .infinity, minHeight: 34)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.accentColor)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(
                            isToday && !isSelected ? Color.accentColor : Color.clear,
                            lineWidth: 1
                        )
                }
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                applySelection(from: cell)
                onDoublePick?(selection)
            }
        )
        .frame(maxWidth: .infinity, minHeight: 34)
        .accessibilityLabel(ScrollMonthDatePickerLogic.isoDate(cell.date, calendar: calendar))
    }

    private func applySelection(from cell: ScrollMonthDatePickerLogic.DayCell) {
        let picked = ScrollMonthDatePickerLogic.normalizedSelection(cell.date, calendar: calendar)
        selection = picked
        onSelect?(picked)
    }

    private func dayForeground(isSelected: Bool, cell: ScrollMonthDatePickerLogic.DayCell) -> Color {
        if isSelected { return .white }
        return cell.isInDisplayedMonth ? .primary : .secondary.opacity(0.55)
    }
}
