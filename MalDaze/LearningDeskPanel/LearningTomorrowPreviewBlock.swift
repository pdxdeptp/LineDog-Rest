import SwiftUI

struct LearningTomorrowPreviewBlock: View {
    let preview: HermesTomorrowPreview

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("明天 \(preview.date)")
                    .font(.caption.weight(.semibold))
                Spacer()
                if preview.isRestDay == true {
                    Text("休息日")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(preview.pendingCount) 节 · \(preview.studyMinutes) 分钟 / \(preview.studyBudget) 分钟")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(preview.tasks) { task in
                HStack(spacing: 6) {
                    Text("\(task.index).")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                    Text(task.title)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text("\(task.durationMinutes)m")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
