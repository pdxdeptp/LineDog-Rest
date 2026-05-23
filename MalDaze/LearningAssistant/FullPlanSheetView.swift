import SwiftUI

struct FullPlanSheetView: View {
    let schedule: [[String: AnyCodable]]
    let totalUnitCount: Int
    let selectedOption: String
    let deadline: String

    @Environment(\.dismiss) private var dismiss

    private var scheduledCount: Int { schedule.count }
    private var unscheduledCount: Int { max(0, totalUnitCount - scheduledCount) }
    private var totalMinutes: Int {
        schedule.compactMap { entry -> Int? in
            entry["target_minutes"]?.value as? Int
        }.reduce(0, +)
    }
    private var optionLabel: String { selectedOption == "A" ? "尽快学完" : "均匀铺开" }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("完整计划 · \(optionLabel)")
                    .font(.headline)
                Spacer()
                Button("关闭") { dismiss() }
                    .buttonStyle(.borderless)
            }
            .padding()

            Divider()

            // Summary row
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 16) {
                    Label("\(totalUnitCount) 集", systemImage: "list.number")
                    Label(String(format: "%.1f 小时", Double(totalMinutes) / 60), systemImage: "clock")
                    Label("截止 \(deadline)", systemImage: "calendar")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if unscheduledCount == 0 {
                    Label("全部 \(totalUnitCount) 集已排入计划", systemImage: "checkmark.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                } else {
                    Label("\(unscheduledCount) 集因容量不足未能排入截止日前", systemImage: "exclamationmark.triangle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.controlBackgroundColor))

            Divider()

            if schedule.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Text("当前参数下无法在截止日前安排任何任务，请调整截止日期或每日学习容量")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                    Spacer()
                }
            } else {
                List {
                    ForEach(Array(schedule.enumerated()), id: \.offset) { _, entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry["unit_title"]?.value as? String ?? "")
                                    .font(.callout)
                                Text(entry["date"]?.value as? String ?? "")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let min = entry["target_minutes"]?.value as? Int {
                                Text("\(min) 分钟")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(minWidth: 400, minHeight: 480)
    }
}
