import SwiftUI

struct LearningWeekLoadView: View {
    let days: [HermesWeekLoadDay]
    let budgetMinutes: Int
    let isLoading: Bool
    let errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("加载周负荷…")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(8)
            } else if days.isEmpty {
                Text("暂无负荷数据。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(days) { day in
                            dayRow(day)
                        }
                    }
                }
            }
        }
    }

    private func dayRow(_ day: HermesWeekLoadDay) -> some View {
        let overCapacity = !day.isRestDay && day.totalMinutes > budgetMinutes
        let maxBar = max(budgetMinutes, day.totalMinutes, 1)
        let fill = CGFloat(day.totalMinutes) / CGFloat(maxBar)
        let cap = budgetMinutes > 0 ? CGFloat(budgetMinutes) / CGFloat(maxBar) : 0

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(shortDate(day.date))
                    .font(.caption.monospacedDigit())
                    .frame(width: 52, alignment: .leading)
                if day.isRestDay {
                    Text("休息")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                } else {
                    Text(LearningCapacityFormatting.formatLoad(
                        totalMinutes: day.totalMinutes,
                        budgetMinutes: budgetMinutes
                    ))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(overCapacity ? .red : .primary)
                }
                Spacer(minLength: 0)
            }

            if !day.isRestDay {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.15))
                        Capsule()
                            .fill(overCapacity ? Color.red.opacity(0.75) : Color.accentColor.opacity(0.65))
                            .frame(width: geo.size.width * min(fill, 1))
                        if cap > 0, cap < 1 {
                            Rectangle()
                                .fill(Color.primary.opacity(0.35))
                                .frame(width: 1)
                                .offset(x: geo.size.width * cap - 0.5)
                        }
                    }
                }
                .frame(height: 6)
            }
        }
    }

    private func shortDate(_ iso: String) -> String {
        guard iso.count >= 10 else { return iso }
        let start = iso.index(iso.startIndex, offsetBy: 5)
        return String(iso[start...])
    }
}
