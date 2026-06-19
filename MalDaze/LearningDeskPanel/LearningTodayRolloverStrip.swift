import SwiftUI

struct LearningTodayRolloverStrip: View {
    let rows: [LearningTaskDisplayRow]
    let onSelect: (String) -> Void

    private static let compactRowThreshold = 4
    private static let scrollableMaxHeight: CGFloat = 132

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("已滚 3+ 天（\(rows.count)）", systemImage: "exclamationmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)

            rowList
        }
        .padding(8)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private var rowList: some View {
        let rowsStack = VStack(alignment: .leading, spacing: 6) {
            ForEach(rows) { row in
                rolloverRow(row)
            }
        }

        if rows.count > Self.compactRowThreshold {
            ScrollView(showsIndicators: false) {
                rowsStack
            }
            .frame(maxHeight: Self.scrollableMaxHeight)
        } else {
            rowsStack
        }
    }

    private func rolloverRow(_ row: LearningTaskDisplayRow) -> some View {
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
