import SwiftUI

struct LearningMovePreviewSheet: View {
    let preview: LearningDeskPanelViewModel.MovePreview
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("确认移动任务")
                .font(.headline)

            Text("「\(preview.taskTitle)」→ \(preview.newDate)")
                .font(.subheadline)

            if preview.changes.count > 1 {
                Text("同项目还将移动 \(preview.changes.count - 1) 项：")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(preview.changes) { change in
                        HStack(alignment: .firstTextBaseline) {
                            Text(change.title)
                                .lineLimit(2)
                            Spacer(minLength: 8)
                            Text("\(change.oldDate) → \(change.newDate)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(maxHeight: 200)

            HStack {
                Button("取消", action: onCancel)
                Spacer()
                Button("应用", action: onConfirm)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(minWidth: 360)
    }
}
