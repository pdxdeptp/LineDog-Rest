import SwiftUI

struct LearningTodayRolloverStrip: View {
    let rows: [LearningTaskDisplayRow]
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("已滚 3+ 天（\(rows.count)）", systemImage: "exclamationmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)

            ForEach(rows) { row in
                Button {
                    onSelect(row.pending.taskId)
                } label: {
                    HStack(spacing: 8) {
                        Text(row.pending.projectName)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                        Text(row.pending.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text("已滚 \(row.autoRollDays) 天")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
